#!/bin/sh
# Install or safely upgrade Sol Advisor's custom-agent templates.

set -eu

usage() {
  cat <<'EOF'
Usage: install-agents.sh [--target-dir <path>] [--check | --upgrade-managed]

Install the seven routed Sol Advisor custom-agent templates into the target directory.
Without --target-dir, the target is "$CODEX_HOME/agents" when CODEX_HOME is already
set, otherwise "$HOME/.codex/agents". Normal installation never overwrites a
differing file.

Options:
  --target-dir <path>  Explicit destination directory (absolute or relative).
  --check              Verify that every destination file already matches exactly;
                       do not create or copy anything.
  --upgrade-managed    Replace only exact recognized Sol Advisor templates, add any
                       missing role, and roll back the batch on failure.
  --help               Show this help text.
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
template_dir=$script_dir/../agents
python_runner=$script_dir/run-python.sh

if [ -n "${CODEX_HOME-}" ]; then
  target_dir=$CODEX_HOME/agents
else
  [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --target-dir explicitly."
  target_dir=$HOME/.codex/agents
fi

mode=install

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-dir)
      [ "$#" -ge 2 ] || fail "--target-dir requires a path."
      [ -n "$2" ] || fail "--target-dir requires a non-empty path."
      case "$2" in
        --*) fail "--target-dir path must be explicit; prefix a relative option-like name with ./ or use an absolute path." ;;
      esac
      target_dir=$2
      shift 2
      ;;
    --check)
      [ "$mode" = install ] || fail "--check and --upgrade-managed are mutually exclusive."
      mode=check
      shift
      ;;
    --upgrade-managed)
      [ "$mode" = install ] || fail "--check and --upgrade-managed are mutually exclusive."
      mode=upgrade-managed
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1 (run with --help for usage)."
      ;;
  esac
done

target_dir=$(sh "$python_runner" - "$target_dir" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).expanduser().resolve(strict=False))
PY
) || fail "could not canonicalize target directory."

[ "$target_dir" != "/" ] || fail "refusing to use the filesystem root as an agent target directory."

exec sh "$python_runner" - "$template_dir" "$target_dir" "$mode" <<'PY'
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile


template_dir = Path(sys.argv[1]).resolve(strict=False)
target_dir = Path(sys.argv[2]).resolve(strict=False)
mode = sys.argv[3]

agent_files = (
    "sol-advisor-investigator.toml",
    "sol-advisor-context-analyst.toml",
    "sol-advisor-mechanical-editor.toml",
    "sol-advisor-test-executor.toml",
    "sol-advisor-local-code-verifier.toml",
    "sol-advisor-final-adjudicator.toml",
    "sol-advisor-spark-worker.toml",
)

# Accept exact LF and CRLF byte forms of recognized managed templates. A differing or
# user-modified file is never treated as managed merely because its TOML is similar.
legacy_hashes = {
    "sol-advisor-investigator.toml": {
        "a15210121b38d954c67633281d4294884dab2244507d5585ae274b610cf54060",
        "4c0b41770beea1d8092193bdaaea4af50ca09ed5174386a9be547d26be0609a3",
        "e215f19fc9239d737084819f1106e82f6d981ea9d7c41a8a284943030fb6af1f",
        "20e69ccac66ea37e239dfd0b5a4fa73ff330fe544abf5f29fce456c687a797f4",
        "5e32f293a1f1947d404b29524edc5c53352ea749fcb86a6418eb2529215ed8c1",
    },
    "sol-advisor-context-analyst.toml": {
        "5ef4f96f1952d87ff90c33aa7293f32af2df1034961aff0c9f5e29123cc13d16",
        "3a038345e1f4ded02c1c13685195cf0251c5005abad88d97b8e288636cb97913",
        "16b00933fb6b02b9163f14309432e58246c26f7aa92341997adb88f3fca3d278",
        "2f919e4359e4be5c93d10ccd4406254b441888e0314f91fd6bfdfc22c42b6836",
        "be9a21c8722c4967b582a667108f45c23cba650a18157b7262609ae6e5b2f79e",
    },
    "sol-advisor-mechanical-editor.toml": {
        "6a6cfa03653344fbc4de7971e529e63b52e7aba7b8edef8342b1410869381475",
        "b2281ec27766dcfd32ea9dda6032da069c37da3f0ab7590936b07804869d0826",
        "ab4cb064cbc71d578e8352d6ee42b4f0153795e47e99a7530a1e30a8aebefc0f",
        "064531ba81ea21ab2ac268c7f59acf0373279ca54f416616fa9b238fabd8bfc9",
        "ecf5ac9d058be5ca48400014000dad7b3a4cf80f1e3b0ac9424adf50aa87cfef",
        "7d9590e1be7f6c8c42b22826f6a3b8987e484658065b1874c76676ee1767e2f4",
        "6465e3796e5e1de30b4845c02e9836479176f057adf033b61a30484b6d542df7",
    },
    "sol-advisor-local-code-verifier.toml": {
        "b4468d367ece3eb151c45c422e21feba719dc69f8029c209af50e34218c0e201",
        "4e553701e1d64e97b96ea62178326e69a33a5142f67bd99493fc7199f010bfaf",
        "74af56e8a3da0aedb79389128b2f0fdfbc010401f36d436e934613c98c366693",
        "109684e6b97fc73d103d2f08434cd54b157f2e01ef4e9303b84898f06e507d7b",
        "9115147d2b04c3a8e844e93360872874396d6b2dc0b8f63d0aa29f24b160e3ab",
    },
    "sol-advisor-final-adjudicator.toml": {
        "e4fac299bb1d4780d5ee81e5f740056aa2db744e81668322670a10347d2342ce",
        "32d8478957cba7b7e254f0745b2ff70ee01cfcc2349b353852240bfb1228265d",
        "3997f5233c87512e4bb5e753af26243de443c36814f7fd8743ff5ead7bab4876",
        "d2a321b6aa2af34a4fb1a309b784fe7c1bb566170abec30d142cceb3d9e98fc0",
        "d1d934debfb1d1dd2db5d6c70e45427a307658b038a1caa2916915f8a7a97745",
    },
    "sol-advisor-spark-worker.toml": {
        "36be86456404373582108586c80b0043ee03ea10b2336362a3c87148412603ca",
        "66f579e38f26252cd78bf123c8a7e3c0db3dd3e6bc63291e2e7d489b4518b68d",
        "afd61bc86e9721c40ff3951953202ac2b2348e2b58aefdb7d1093aae855668e6",
        "b9fdecbb1ba7b7072c759ca65546b108d69d7ad8f6a44321c4a25a46af8bb873",
    },
}


def fail(message: str) -> None:
    raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def regular_file(path: Path) -> bool:
    try:
        value = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISREG(value.st_mode) and not path.is_symlink()


def remove_transaction_dir(path: Path) -> None:
    if not path.exists():
        return
    for child in path.iterdir():
        if child.is_dir() or child.is_symlink():
            fail(f"unexpected transaction entry cannot be cleaned safely: {child}")
        child.unlink()
    path.rmdir()


actual_templates = {path.name for path in template_dir.glob("*.toml")}
if actual_templates != set(agent_files):
    fail(f"unexpected shipped agent template set: {sorted(actual_templates ^ set(agent_files))}")

template_hashes: dict[str, str] = {}
for name in agent_files:
    path = template_dir / name
    if not regular_file(path):
        fail(f"shipped template is missing or not a regular file: {path}")
    template_hashes[name] = sha256(path)

target_existed = target_dir.exists()
if target_existed and (not target_dir.is_dir() or target_dir.is_symlink()):
    fail(f"target directory is not a real directory: {target_dir}")

actions: list[tuple[str, str, str | None]] = []
errors: list[str] = []
for name in agent_files:
    destination = target_dir / name
    if not destination.exists() and not destination.is_symlink():
        if mode == "check":
            errors.append(f"required installed agent file is missing: {destination}")
        else:
            actions.append((name, "add", None))
        continue
    if not regular_file(destination):
        errors.append(f"destination is not a regular file and will not be replaced: {destination}")
        continue
    existing_hash = sha256(destination)
    if existing_hash == template_hashes[name]:
        actions.append((name, "current", existing_hash))
    elif mode == "upgrade-managed" and existing_hash in legacy_hashes.get(name, set()):
        actions.append((name, "replace", existing_hash))
    else:
        errors.append(f"destination differs from a current or recognized managed template: {destination}")

if errors:
    for message in errors:
        print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

if mode == "check":
    print(f"CHECK PASSED: all Sol Advisor agent files exactly match {template_dir}.")
    raise SystemExit(0)

target_created = False
transaction_dir: Path | None = None
applied: list[tuple[str, str]] = []
messages: list[str] = []

try:
    if not target_existed:
        target_dir.mkdir(parents=True, exist_ok=False)
        target_created = True

    transaction_dir = Path(tempfile.mkdtemp(prefix=".sol-advisor-agents.", dir=target_dir))
    staged: dict[str, Path] = {}
    backups: dict[str, Path] = {}

    # Stage every template and every replacement backup before changing a destination.
    for name in agent_files:
        staged_path = transaction_dir / f"new-{name}"
        shutil.copy2(template_dir / name, staged_path)
        if sha256(staged_path) != template_hashes[name]:
            fail(f"staged template exactness check failed: {name}")
        staged[name] = staged_path

    for name, action, expected_hash in actions:
        if action != "replace":
            continue
        destination = target_dir / name
        if not regular_file(destination) or sha256(destination) != expected_hash:
            fail(f"destination changed after preflight and will not be replaced: {destination}")
        backup = transaction_dir / f"old-{name}"
        shutil.copy2(destination, backup)
        if sha256(backup) != expected_hash:
            fail(f"could not capture an exact rollback copy: {destination}")
        backups[name] = backup

    raw_fail_after = os.environ.get("SOL_ADVISOR_INSTALL_TEST_FAIL_AFTER")
    fail_after = int(raw_fail_after) if raw_fail_after else None
    if fail_after is not None and fail_after < 1:
        fail("SOL_ADVISOR_INSTALL_TEST_FAIL_AFTER must be a positive integer")

    for name, action, expected_hash in actions:
        destination = target_dir / name
        if action == "current":
            if not regular_file(destination) or sha256(destination) != template_hashes[name]:
                fail(f"current destination changed after preflight: {destination}")
            messages.append(f"ALREADY CURRENT: {destination}")
            continue

        if action == "add":
            if destination.exists() or destination.is_symlink():
                fail(f"destination appeared after preflight and will not be overwritten: {destination}")
            os.link(staged[name], destination)
            applied.append((name, action))
            messages.append(f"INSTALLED: {destination}")
        elif action == "replace":
            if not regular_file(destination) or sha256(destination) != expected_hash:
                fail(f"destination changed after preflight and will not be replaced: {destination}")
            os.replace(staged[name], destination)
            applied.append((name, action))
            messages.append(f"UPGRADED MANAGED: {destination}")
        else:
            fail(f"unknown planned installer action: {action}")

        if fail_after is not None and len(applied) == fail_after:
            fail("simulated managed-upgrade failure for rollback verification")

    for name in agent_files:
        destination = target_dir / name
        if not regular_file(destination) or sha256(destination) != template_hashes[name]:
            fail(f"post-install exactness check failed: {destination}")

except Exception as error:
    rollback_errors: list[str] = []
    for name, action in reversed(applied):
        destination = target_dir / name
        try:
            if action == "add":
                if regular_file(destination) and sha256(destination) == template_hashes[name]:
                    destination.unlink()
                else:
                    rollback_errors.append(f"added destination changed and was preserved: {destination}")
            elif action == "replace":
                backup = transaction_dir / f"old-{name}" if transaction_dir else None
                if backup is None or not regular_file(backup):
                    rollback_errors.append(f"rollback copy is unavailable: {destination}")
                elif not regular_file(destination) or sha256(destination) != template_hashes[name]:
                    rollback_errors.append(f"upgraded destination changed and was preserved: {destination}")
                else:
                    os.replace(backup, destination)
        except Exception as rollback_error:
            rollback_errors.append(f"{destination}: {rollback_error}")

    try:
        if transaction_dir is not None:
            remove_transaction_dir(transaction_dir)
        if target_created and target_dir.exists() and not any(target_dir.iterdir()):
            target_dir.rmdir()
    except Exception as cleanup_error:
        rollback_errors.append(str(cleanup_error))

    print(f"ERROR: {error}", file=sys.stderr)
    if rollback_errors:
        for message in rollback_errors:
            print(f"ERROR: rollback incomplete: {message}", file=sys.stderr)
    else:
        print("ROLLBACK PASSED: installer changes were reverted.", file=sys.stderr)
    raise SystemExit(1)

remove_transaction_dir(transaction_dir)
for message in messages:
    print(message)
print(f"INSTALL PASSED: all Sol Advisor agent files exactly match {template_dir}.")
PY
