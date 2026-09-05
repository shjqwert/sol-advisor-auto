#!/usr/bin/env python3
"""Plan or prepare CodeGraph and Serena indexes for one exact repository root."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import xml.etree.ElementTree as ET


GENERATED_EXCLUSIONS = [
    ".codegraph/**",
    ".serena/cache/**",
    ".serena/indices/**",
    "**/__pycache__/**",
    "**/.pytest_cache/**",
    "**/.mypy_cache/**",
]

SERENA_LANGUAGE_BY_SUFFIX = {
    ".py": "python",
    ".pyi": "python",
    ".c": "cpp",
    ".h": "cpp",
    ".cc": "cpp",
    ".cpp": "cpp",
    ".cxx": "cpp",
    ".hpp": "cpp",
    ".js": "typescript",
    ".jsx": "typescript",
    ".ts": "typescript",
    ".tsx": "typescript",
    ".rs": "rust",
    ".java": "java",
    ".kt": "kotlin",
    ".kts": "kotlin",
    ".go": "go",
    ".rb": "ruby",
    ".dart": "dart",
    ".php": "php",
    ".r": "r",
    ".pl": "perl",
    ".clj": "clojure",
    ".ex": "elixir",
    ".exs": "elixir",
    ".swift": "swift",
    ".sh": "bash",
    ".bash": "bash",
    ".ps1": "powershell",
    ".lua": "lua",
    ".zig": "zig",
    ".scala": "scala",
    ".fs": "fsharp",
    ".fsx": "fsharp",
    ".hs": "haskell",
    ".vue": "vue",
    ".svelte": "svelte",
}


def run(command: list[str], *, cwd: Path) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
    except OSError as exc:
        return subprocess.CompletedProcess(command, 127, "", str(exc))


class SnapshotError(RuntimeError):
    """The workspace state could not be read reliably."""


def snapshot_path_identity(path: Path) -> tuple[str, str]:
    try:
        metadata = path.lstat()
        if stat.S_ISLNK(metadata.st_mode):
            target = os.readlink(path)
            return "symlink", hashlib.sha256(os.fsencode(target)).hexdigest()
        if stat.S_ISREG(metadata.st_mode):
            digest = hashlib.sha256()
            with path.open("rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
            return "file", digest.hexdigest()
        if stat.S_ISDIR(metadata.st_mode):
            return "directory", ""
        return "other", hashlib.sha256(str(metadata.st_mode).encode()).hexdigest()
    except FileNotFoundError:
        return "missing", ""
    except OSError as exc:
        raise SnapshotError(f"cannot read protected path {path}: {exc}") from exc


def snapshot_paths(root: Path, relatives: list[str]) -> tuple[set[str], str]:
    records: list[str] = []
    protected: set[str] = set()
    for raw in sorted(set(relatives)):
        relative = raw.replace("\\", "/").strip("/")
        candidate = Path(relative)
        if not relative or candidate.is_absolute() or ".." in candidate.parts:
            raise SnapshotError(f"invalid protected path from workspace enumeration: {raw!r}")
        if is_generated_path(relative):
            continue
        kind, content_hash = snapshot_path_identity(root / candidate)
        protected.add(relative)
        records.append(f"{relative}|{kind}|{content_hash}")
    return protected, hashlib.sha256("\n".join(records).encode()).hexdigest()


def git_change_snapshot(root: Path) -> tuple[set[str], str]:
    result = run(
        ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--"],
        cwd=root,
    )
    if result.returncode != 0:
        raise SnapshotError(f"cannot enumerate Git protected paths: {tail(result.stderr or result.stdout)}")
    return snapshot_paths(root, [value for value in result.stdout.split("\0") if value])


def same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(os.path.abspath(left)) == os.path.normcase(os.path.abspath(right))


def has_workspace_marker(root: Path, name: str) -> bool:
    try:
        (root / name).lstat()
        return True
    except FileNotFoundError:
        return False
    except OSError as exc:
        raise SnapshotError(f"cannot inspect {name} workspace marker: {exc}") from exc


def detect_workspace_kind(root: Path) -> str:
    git_marker = has_workspace_marker(root, ".git")
    git_root = run(["git", "-C", str(root), "rev-parse", "--show-toplevel"], cwd=root)
    if git_root.returncode == 0 and git_root.stdout.strip():
        if not same_path(root, Path(git_root.stdout.strip()).resolve(strict=True)):
            raise ValueError("a Git workspace must be the exact worktree root")
        return "git"
    if git_marker:
        # Preserve the Git classification so the protected-path snapshot can
        # report a failed VCS check instead of silently confirming a directory.
        return "git"
    svn_marker = has_workspace_marker(root, ".svn")
    svn_info = run(["svn", "info", "--show-item", "wc-root", str(root)], cwd=root)
    if svn_info.returncode == 0:
        return "svn"
    return "svn" if svn_marker else "directory"


def is_generated_path(relative: str) -> bool:
    normalized = relative.replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    normalized = normalized.lstrip("/")
    return normalized == ".codegraph" or normalized.startswith((
        ".codegraph/",
        ".serena/",
        "__pycache__/",
    )) or any(part in {"__pycache__", ".pytest_cache", ".mypy_cache"} for part in normalized.split("/"))


def filesystem_files(root: Path) -> list[str]:
    excluded_directories = {
        ".git", ".svn", ".codegraph", ".serena",
        "__pycache__", ".pytest_cache", ".mypy_cache",
    }
    files: list[str] = []
    for current, directories, filenames in os.walk(root):
        directories[:] = [name for name in directories if name not in excluded_directories]
        current_path = Path(current)
        for filename in filenames:
            relative = (current_path / filename).relative_to(root).as_posix()
            if not is_generated_path(relative):
                files.append(relative)
    return files


def workspace_files(root: Path, kind: str) -> list[str]:
    if kind == "git":
        listed = run(["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard"], cwd=root)
    elif kind == "svn":
        listed = run(["svn", "list", "--recursive", str(root)], cwd=root)
    else:
        return filesystem_files(root)
    if listed.returncode != 0:
        return filesystem_files(root)
    return [
        line.strip().replace("\\", "/")
        for line in listed.stdout.splitlines()
        if line.strip() and not line.rstrip().endswith("/") and not is_generated_path(line.strip())
    ]


def snapshot_directory_files(root: Path) -> list[str]:
    excluded = {".git", ".svn", ".codegraph", ".serena", "__pycache__", ".pytest_cache", ".mypy_cache"}
    files: list[str] = []

    def failed(error: OSError) -> None:
        raise SnapshotError(f"cannot enumerate protected directory: {error}")

    for current, directories, filenames in os.walk(root, onerror=failed):
        directories[:] = [name for name in directories if name not in excluded]
        current_path = Path(current)
        for filename in filenames:
            relative = (current_path / filename).relative_to(root).as_posix()
            if not is_generated_path(relative):
                files.append(relative)
    return files


def svn_change_snapshot(root: Path) -> tuple[set[str], str]:
    result = run(["svn", "status", "--xml", "--ignore-externals", str(root)], cwd=root)
    if result.returncode != 0:
        raise SnapshotError(f"cannot inspect SVN protected paths: {tail(result.stderr or result.stdout)}")
    try:
        ET.fromstring(result.stdout)
    except ET.ParseError as exc:
        raise SnapshotError("cannot parse SVN protected-path status") from exc
    return snapshot_paths(root, snapshot_directory_files(root))


def directory_change_snapshot(root: Path) -> tuple[set[str], str]:
    return snapshot_paths(root, snapshot_directory_files(root))


def workspace_change_snapshot(root: Path, kind: str) -> tuple[set[str], str]:
    if kind == "git":
        return git_change_snapshot(root)
    if kind == "svn":
        return svn_change_snapshot(root)
    return directory_change_snapshot(root)


def tail(text: str, limit: int = 2000) -> str:
    value = text.strip()
    return value[-limit:] if len(value) > limit else value


def command_prefix(name: str) -> list[str] | None:
    resolved = shutil.which(name)
    if resolved is None:
        return None
    if os.name == "nt" and Path(resolved).suffix.lower() in {".cmd", ".bat"}:
        return [os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", resolved]
    return [resolved]


def infer_serena_languages(root: Path, workspace_kind: str) -> list[str]:
    counts: dict[str, int] = {}
    for relative in workspace_files(root, workspace_kind):
        language = SERENA_LANGUAGE_BY_SUFFIX.get(Path(relative.strip()).suffix.lower())
        if language:
            counts[language] = counts.get(language, 0) + 1
    return sorted(counts, key=lambda language: (-counts[language], language))


def plan_operations(root: Path, policy: str, workspace_kind: str) -> list[dict[str, object]]:
    serena_languages = infer_serena_languages(root, workspace_kind)
    tools: dict[str, dict[str, object]] = {
        "codegraph": {
            "prefix": command_prefix("codegraph"),
            "indexed": (root / ".codegraph").is_dir(),
        },
        "serena": {
            "prefix": command_prefix("serena"),
            "indexed": (root / ".serena" / "project.yml").is_file(),
        },
    }
    operations: list[dict[str, object]] = []
    for name, state in tools.items():
        command: list[str] | None = None
        reason = "reuse existing index"
        if policy == "never":
            reason = "indexing disabled by policy"
        elif policy == "reuse":
            reason = "reuse existing index" if state["indexed"] else "index missing; use fallback search"
        elif not state["indexed"]:
            if name == "codegraph":
                arguments = ["init", str(root)]
            else:
                if not serena_languages:
                    arguments = []
                else:
                    arguments = ["project", "index", str(root), "--name", root.name]
                    for language in serena_languages:
                        arguments.extend(["--language", language])
            command = [*state["prefix"], *arguments] if state["prefix"] and arguments else None
            reason = "create missing index" if arguments else "no supported source language detected; use fallback search"
        elif policy == "refresh":
            arguments = ["sync", str(root)] if name == "codegraph" else ["project", "index", str(root)]
            command = [*state["prefix"], *arguments] if state["prefix"] else None
            reason = "refresh existing index"
        if state["prefix"] is None and policy not in {"never", "reuse"}:
            reason = "tool unavailable; use fallback search"
        operations.append(
            {
                "tool": name,
                "available": state["prefix"] is not None,
                "indexed_before": state["indexed"],
                "detected_languages": serena_languages if name == "serena" else [],
                "reason": reason,
                "command": command,
            }
        )
    return operations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository", help="Exact Git, SVN, or plain workspace root")
    parser.add_argument(
        "--indexing",
        choices=("reuse", "create-if-missing", "refresh", "never"),
        default="create-if-missing",
    )
    parser.add_argument("--apply", action="store_true", help="Execute planned index creation or refresh")
    args = parser.parse_args()

    root = Path(args.repository).expanduser().resolve(strict=True)
    if not root.is_dir():
        parser.error("workspace must resolve to an existing directory")
    try:
        workspace_kind = detect_workspace_kind(root)
    except (ValueError, SnapshotError) as exc:
        parser.error(str(exc))

    operations = plan_operations(root, args.indexing, workspace_kind)
    failed = False
    snapshot_errors: list[str] = []
    snapshot_ready = False
    changed_before: set[str] = set()
    fingerprint_before = ""
    try:
        changed_before, fingerprint_before = workspace_change_snapshot(root, workspace_kind)
        snapshot_ready = True
    except SnapshotError as exc:
        snapshot_errors.append(str(exc))
        failed = True

    if args.apply and snapshot_ready:
        for operation in operations:
            command = operation["command"]
            if not command:
                operation["status"] = "skipped"
                continue
            result = run(command, cwd=root)
            operation["status"] = "completed" if result.returncode == 0 else "failed"
            operation["returncode"] = result.returncode
            if result.returncode != 0:
                operation["diagnostic"] = tail(result.stderr or result.stdout)
                failed = True
    elif args.apply:
        for operation in operations:
            operation["status"] = "blocked" if operation["command"] else "skipped"
    else:
        for operation in operations:
            operation["status"] = "planned" if operation["command"] else "skipped"

    new_working_changes: list[str] = []
    working_changes_modified: bool | None = None
    if snapshot_ready:
        try:
            changed_after, fingerprint_after = workspace_change_snapshot(root, workspace_kind)
            new_working_changes = sorted(changed_after - changed_before)
            working_changes_modified = fingerprint_after != fingerprint_before
            if new_working_changes or working_changes_modified:
                failed = True
        except SnapshotError as exc:
            snapshot_errors.append(str(exc))
            failed = True

    read_only_state = "unconfirmed" if snapshot_errors else ("changed" if working_changes_modified else "confirmed_unchanged")
    output = {
        "valid": not failed,
        "repository": str(root),
        "workspace_kind": workspace_kind,
        "indexing": args.indexing,
        "applied": args.apply,
        "operations": operations,
        "new_working_changes": new_working_changes,
        "working_changes_modified": working_changes_modified,
        "read_only_state": read_only_state,
        "snapshot_errors": snapshot_errors,
        "raw_search_exclusions": GENERATED_EXCLUSIONS,
        "fallback": "exact text search and targeted reads remain available when an index tool is unavailable",
    }
    print(json.dumps(output, ensure_ascii=False, separators=(",", ":")))
    return 0 if not failed else 2


if __name__ == "__main__":
    sys.exit(main())
