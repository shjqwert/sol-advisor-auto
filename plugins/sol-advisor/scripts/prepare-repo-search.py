#!/usr/bin/env python3
"""Plan or prepare CodeGraph and Serena indexes for one exact repository root."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


GENERATED_EXCLUSIONS = [
    ".codegraph/**",
    ".serena/cache/**",
    ".serena/indices/**",
    "**/__pycache__/**",
    "**/.pytest_cache/**",
    "**/.mypy_cache/**",
]


def run(command: list[str], *, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def git_changed_paths(root: Path) -> set[str]:
    result = run(
        ["git", "-C", str(root), "diff", "--name-only", "--no-ext-diff", "HEAD", "--"],
        cwd=root,
    )
    if result.returncode != 0:
        return set()
    return {line.strip().replace("\\", "/") for line in result.stdout.splitlines() if line.strip()}


def git_diff_fingerprint(root: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "diff", "--binary", "HEAD", "--"],
        cwd=root,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return ""
    return hashlib.sha256(result.stdout).hexdigest()


def tail(text: str, limit: int = 2000) -> str:
    value = text.strip()
    return value[-limit:] if len(value) > limit else value


def plan_operations(root: Path, policy: str) -> list[dict[str, object]]:
    tools = {
        "codegraph": {
            "available": shutil.which("codegraph") is not None,
            "indexed": (root / ".codegraph").is_dir(),
        },
        "serena": {
            "available": shutil.which("serena") is not None,
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
            command = ["codegraph", "init", str(root)] if name == "codegraph" else ["serena", "project", "index", str(root)]
            reason = "create missing index"
        elif policy == "refresh":
            command = ["codegraph", "sync", str(root)] if name == "codegraph" else ["serena", "project", "index", str(root)]
            reason = "refresh existing index"
        if command is not None and not state["available"]:
            command = None
            reason = "tool unavailable; use fallback search"
        operations.append(
            {
                "tool": name,
                "available": state["available"],
                "indexed_before": state["indexed"],
                "reason": reason,
                "command": command,
            }
        )
    return operations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository", help="Exact repository root; must contain .git")
    parser.add_argument(
        "--indexing",
        choices=("reuse", "create-if-missing", "refresh", "never"),
        default="create-if-missing",
    )
    parser.add_argument("--apply", action="store_true", help="Execute planned index creation or refresh")
    args = parser.parse_args()

    root = Path(args.repository).expanduser().resolve(strict=True)
    if not root.is_dir() or not (root / ".git").exists():
        parser.error("repository must resolve to an exact Git repository root containing .git")

    operations = plan_operations(root, args.indexing)
    tracked_before = git_changed_paths(root)
    tracked_fingerprint_before = git_diff_fingerprint(root)
    failed = False
    if args.apply:
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
    else:
        for operation in operations:
            operation["status"] = "planned" if operation["command"] else "skipped"

    tracked_after = git_changed_paths(root)
    tracked_fingerprint_after = git_diff_fingerprint(root)
    new_tracked_changes = sorted(tracked_after - tracked_before)
    tracked_diff_changed = tracked_fingerprint_after != tracked_fingerprint_before
    if new_tracked_changes or tracked_diff_changed:
        failed = True

    output = {
        "valid": not failed,
        "repository": str(root),
        "indexing": args.indexing,
        "applied": args.apply,
        "operations": operations,
        "new_tracked_changes": new_tracked_changes,
        "tracked_diff_changed": tracked_diff_changed,
        "raw_search_exclusions": GENERATED_EXCLUSIONS,
        "fallback": "exact text search and targeted reads remain available when an index tool is unavailable",
    }
    print(json.dumps(output, ensure_ascii=False, separators=(",", ":")))
    return 0 if not failed else 2


if __name__ == "__main__":
    sys.exit(main())
