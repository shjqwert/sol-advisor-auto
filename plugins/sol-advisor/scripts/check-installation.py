#!/usr/bin/env python3
"""Read-only source/cache/agent installation check; never installs or overwrites files."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def digest(path: Path) -> str | None:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def check_installation(source: Path, cache: Path, agents: Path) -> dict:
    problems: list[dict[str, str]] = []
    count = 0
    for file in sorted(source.rglob("*")):
        if not file.is_file() or "__pycache__" in file.parts:
            continue
        relative = file.relative_to(source)
        count += 1
        if digest(file) != digest(cache / relative):
            problems.append({"surface": "plugin-cache", "file": relative.as_posix()})
    templates = sorted((source / "agents").glob("sol-advisor-*.toml"))
    if len(templates) != 5:
        problems.append({"surface": "source", "file": "expected five agent templates"})
    for name in ("sol-advisor-investigator.toml", "sol-advisor-test-executor.toml"):
        if (agents / name).exists() or (agents / name).is_symlink():
            problems.append({"surface": "retired-native-agent", "file": name})
    for file in templates:
        if digest(file) != digest(agents / file.name):
            problems.append({"surface": "native-agent", "file": file.name})
    if cache.is_dir():
        for file in cache.rglob("*"):
            if file.is_file() and not any(part in {"__pycache__", ".serena", ".codegraph"} for part in file.relative_to(cache).parts):
                if not (source / file.relative_to(cache)).exists():
                    problems.append({"surface": "extra-cache-file", "file": file.relative_to(cache).as_posix()})
    return {"ok": not problems, "pluginFilesChecked": count, "agentFilesChecked": len(templates), "differences": problems}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--codex-home", type=Path, default=Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")))
    parser.add_argument("--cache", type=Path, help="Explicit cache for offline verification; does not verify Codex registration.")
    args = parser.parse_args()
    manifest = json.loads((args.source / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))
    if manifest["name"] != "sol-advisor":
        raise ValueError("Source is not the Sol Advisor plugin")
    registered = args.cache is None
    enabled = None
    if registered:
        command = shutil.which("codex.cmd" if os.name == "nt" else "codex")
        if command is None:
            raise ValueError("Codex CLI is unavailable; --cache supports offline verification only")
        prefix = ["cmd.exe", "/d", "/c", command] if os.name == "nt" else [command]
        listing = json.loads(subprocess.check_output(prefix + ["plugin", "list", "--json"], encoding="utf-8",
            env={**os.environ, "CODEX_HOME": str(args.codex_home.resolve())}))
        entry = next((item for item in listing["installed"] if item["pluginId"] == "sol-advisor@sol-advisor"), None)
        if entry is None:
            raise ValueError("Sol Advisor is not installed")
        version = entry["version"]
        if not isinstance(version, str) or not version or "/" in version or "\\" in version or version in {".", ".."}:
            raise ValueError("Invalid installed version")
        cache = args.codex_home / "plugins/cache/sol-advisor/sol-advisor" / version
        enabled = entry["enabled"]
    else:
        cache = args.cache
    report = check_installation(args.source, cache, args.codex_home / "agents")
    report.update(registrationVerified=registered, enabled=enabled, sourceVersion=manifest["version"])
    if registered and (not enabled or version != manifest["version"]):
        report["ok"] = False
        report["differences"].append({"surface": "registration", "file": "version or enabled state differs"})
    print(json.dumps(report, ensure_ascii=True, indent=2))
    raise SystemExit(0 if report["ok"] else 1)


if __name__ == "__main__":
    main()
