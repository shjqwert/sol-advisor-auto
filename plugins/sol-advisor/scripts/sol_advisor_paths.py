#!/usr/bin/env python3
"""Resolve and validate workspace-local Sol Advisor run artifact paths."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess


def fail(message: str) -> None:
    raise ValueError(message)


def same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(os.path.abspath(left)) == os.path.normcase(os.path.abspath(right))


def run_quiet(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)
    except OSError:
        return None


def resolve_workspace(workspace_arg: str) -> tuple[Path, Path, str]:
    declared = Path(workspace_arg).expanduser().resolve(strict=True)
    if not declared.is_dir():
        fail("workspace must be an existing directory")

    git_root = run_quiet(["git", "-C", str(declared), "rev-parse", "--show-toplevel"], declared)
    if git_root is not None and git_root.returncode == 0 and git_root.stdout.strip():
        root = Path(git_root.stdout.strip()).resolve(strict=True)
        if not same_path(declared, root):
            fail("a Git workspace must be the exact worktree root")
        git_dir_result = run_quiet(
            ["git", "-C", str(declared), "rev-parse", "--absolute-git-dir"], declared
        )
        if git_dir_result is None or git_dir_result.returncode != 0 or not git_dir_result.stdout.strip():
            fail("Git administrative directory could not be resolved")
        git_dir = Path(git_dir_result.stdout.strip()).resolve(strict=True)
        if not git_dir.is_dir():
            fail("Git administrative directory is not an existing directory")
        return root, git_dir / "sol-advisor", "git"

    svn_info = run_quiet(["svn", "info", "--show-item", "wc-root", str(declared)], declared)
    workspace_kind = "svn" if svn_info is not None and svn_info.returncode == 0 else "directory"
    return declared, declared / ".sol-advisor", workspace_kind


def ensure_directory(path: Path) -> Path:
    if path.exists():
        if path.is_symlink() or not path.is_dir():
            fail(f"run artifact directory must be a real directory: {path}")
    else:
        path.mkdir()
    return path


def run_base_paths(storage_root: Path, run_id: str) -> dict[str, Path]:
    run_dir = storage_root / "runs" / run_id
    return {
        "run_dir": run_dir,
        "state": run_dir / "state.json",
        "plans_dir": run_dir / "plans",
        "results_dir": run_dir / "results",
        "visible_dir": run_dir / "visible",
        "runtime_dir": run_dir / "runtime",
    }


def ensure_run_base(storage_root: Path, run_id: str) -> dict[str, Path]:
    paths = run_base_paths(storage_root, run_id)
    advisor_dir = ensure_directory(storage_root)
    ensure_directory(advisor_dir / "runs")
    ensure_directory(paths["run_dir"])
    plans_dir = ensure_directory(paths["plans_dir"])
    results_dir = ensure_directory(paths["results_dir"])
    visible_dir = ensure_directory(paths["visible_dir"])
    runtime_dir = ensure_directory(paths["runtime_dir"])
    run_dir = paths["run_dir"]
    return {
        "run_dir": run_dir,
        "state": paths["state"],
        "plans_dir": plans_dir,
        "results_dir": results_dir,
        "visible_dir": visible_dir,
        "runtime_dir": runtime_dir,
    }


def ensure_run_layout(storage_root: Path, run_id: str, batch_id: str) -> dict[str, Path]:
    base = ensure_run_base(storage_root, run_id)
    run_dir = base["run_dir"]
    plans_dir = base["plans_dir"]
    results_dir = base["results_dir"]
    visible_dir = base["visible_dir"]
    runtime_dir = base["runtime_dir"]
    result_batch_dir = ensure_directory(results_dir / batch_id)
    visible_batch_dir = ensure_directory(visible_dir / batch_id)
    runtime_batch_dir = ensure_directory(runtime_dir / batch_id)
    return {
        "run_dir": run_dir,
        "state": base["state"],
        "plan": plans_dir / f"{batch_id}.json",
        "result_batch_dir": result_batch_dir,
        "visible_batch_dir": visible_batch_dir,
        "runtime_batch_dir": runtime_batch_dir,
    }


def route_paths(layout: dict[str, Path], response_token: str) -> dict[str, Path]:
    return {
        "result": layout["result_batch_dir"] / f"{response_token}.json",
        "visible": layout["visible_batch_dir"] / f"{response_token}.md",
        "runtime": layout["runtime_batch_dir"] / f"{response_token}.json",
    }


def require_exact_path(path_arg: str | Path, expected: Path, label: str, *, must_exist: bool) -> Path:
    provided = Path(path_arg)
    if not same_path(provided, expected):
        fail(f"{label} must use the workspace-local run path: {expected}")
    if provided.is_symlink():
        fail(f"{label} must not be a symlink")
    if must_exist and not provided.is_file():
        fail(f"{label} must be an existing regular file")
    return provided
