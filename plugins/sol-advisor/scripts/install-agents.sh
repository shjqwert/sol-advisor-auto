#!/bin/sh
# Install or safely upgrade Sol Advisor's custom-agent templates.

set -eu

usage() {
  cat <<'EOF'
Usage: install-agents.sh [--target-dir <path>] [--check | --upgrade-managed]

Install the five routed Sol Advisor custom-agent templates into the target directory.
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
    "sol-advisor-context-analyst.toml",
    "sol-advisor-mechanical-editor.toml",
    "sol-advisor-local-code-verifier.toml",
    "sol-advisor-final-adjudicator.toml",
    "sol-advisor-spark-worker.toml",
)

# Accept exact LF and CRLF byte forms of recognized managed templates. A differing or
# user-modified file is never treated as managed merely because its TOML is similar.
legacy_hashes = {
    # Exact templates from repository commit 293266924b, in LF and CRLF forms.
    "sol-advisor-investigator.toml": {
        "d00452d78240116576dc296db5042b072265593c72c639a4ac20cf1b02566b4b",
        "51105fca90b99eea537dea154f35f4a6f08198bdcdb87c7373e2049b588da91c",
        "a15210121b38d954c67633281d4294884dab2244507d5585ae274b610cf54060",
        "4c0b41770beea1d8092193bdaaea4af50ca09ed5174386a9be547d26be0609a3",
        "e215f19fc9239d737084819f1106e82f6d981ea9d7c41a8a284943030fb6af1f",
        "20e69ccac66ea37e239dfd0b5a4fa73ff330fe544abf5f29fce456c687a797f4",
        "5e32f293a1f1947d404b29524edc5c53352ea749fcb86a6418eb2529215ed8c1",
    },
    "sol-advisor-context-analyst.toml": {
        "1f8749ba64e85abc4e6cea902f748391e19eec281bfa2b88480da9f24d3666cf",
        "bfd2f630806ab0615812de651dbad114a92c34a877dcd4fcabe5999ee6ca8023",
        "5ef4f96f1952d87ff90c33aa7293f32af2df1034961aff0c9f5e29123cc13d16",
        "3a038345e1f4ded02c1c13685195cf0251c5005abad88d97b8e288636cb97913",
        "16b00933fb6b02b9163f14309432e58246c26f7aa92341997adb88f3fca3d278",
        "2f919e4359e4be5c93d10ccd4406254b441888e0314f91fd6bfdfc22c42b6836",
        "be9a21c8722c4967b582a667108f45c23cba650a18157b7262609ae6e5b2f79e",
    },
    "sol-advisor-mechanical-editor.toml": {
        "b3deac0da749c53fdcf50db5acd3175f2c1f78eb14c1cbb45783fc3862a27649",
        "e70cb65715129b7c408ab26a9ba47e2cac9139e07d954be79654c20df8c3a6ba",
        "6a6cfa03653344fbc4de7971e529e63b52e7aba7b8edef8342b1410869381475",
        "b2281ec27766dcfd32ea9dda6032da069c37da3f0ab7590936b07804869d0826",
        "ab4cb064cbc71d578e8352d6ee42b4f0153795e47e99a7530a1e30a8aebefc0f",
        "064531ba81ea21ab2ac268c7f59acf0373279ca54f416616fa9b238fabd8bfc9",
        "ecf5ac9d058be5ca48400014000dad7b3a4cf80f1e3b0ac9424adf50aa87cfef",
        "7d9590e1be7f6c8c42b22826f6a3b8987e484658065b1874c76676ee1767e2f4",
        "6465e3796e5e1de30b4845c02e9836479176f057adf033b61a30484b6d542df7",
        "6b357bb7433e7d3dcd2ffb30d92e693d3462f45819331abbfb55008f6e82f8fc",
        "d789215b7e53a09c66ab832eabf156b449043dfccf3f2dd054712baefa624e99",
    },
    "sol-advisor-local-code-verifier.toml": {
        "c41da16c26ea6ded200699ee31d02e4680cc997d994370e4353ba5b96ae60ac8",
        "9de27c0d181db0ddfd81d5bd82d6a789affbcd616fe91b7939104e46f1c6d025",
        "e4f8a5a7364e1e9eadd0974fd21d9242956f161cfaa769cd7f686370ced92671",
        "2ea57feb5af143c2f597f69b0b253ca2db6f27d44a506b0775b1db2fab13950e",
        "234fb934016ff4ccf16db0c841e0cec4d92370a282b4f37961118e947cfae93b",
        "7fecc3d56c0ab4fa9e64ea72f80ed41678d7fcf97bf5043ade696d580b7b2fcc",
        "b4468d367ece3eb151c45c422e21feba719dc69f8029c209af50e34218c0e201",
        "4e553701e1d64e97b96ea62178326e69a33a5142f67bd99493fc7199f010bfaf",
        "74af56e8a3da0aedb79389128b2f0fdfbc010401f36d436e934613c98c366693",
        "109684e6b97fc73d103d2f08434cd54b157f2e01ef4e9303b84898f06e507d7b",
        "9115147d2b04c3a8e844e93360872874396d6b2dc0b8f63d0aa29f24b160e3ab",
    },
    "sol-advisor-final-adjudicator.toml": {
        "a9a758bd8228d97f56e87316a789857aa6714bc604e80d8387efd0556ad93dde",
        "2b218115a97e15ce810b6112fc3e4a101fcd6a0454eda42241b302d8d4d40ae8",
        "ba2ee3bb3a0ec6b6776ab77cc3bca6f3da47cb0b713e073ae3a45e9cca902916",
        "a6328ada966d35521df92f9afc4075f676b90256f6008d66fb3301e39e874fe8",
        "e4fac299bb1d4780d5ee81e5f740056aa2db744e81668322670a10347d2342ce",
        "32d8478957cba7b7e254f0745b2ff70ee01cfcc2349b353852240bfb1228265d",
        "3997f5233c87512e4bb5e753af26243de443c36814f7fd8743ff5ead7bab4876",
        "d2a321b6aa2af34a4fb1a309b784fe7c1bb566170abec30d142cceb3d9e98fc0",
        "d1d934debfb1d1dd2db5d6c70e45427a307658b038a1caa2916915f8a7a97745",
        "eddfc8d4d11fb22ed748407fd339862e4b23c62f3f9ba0a632089d69ca963622",
        "e8f9ecc73aa32387aad747a3e8cc26854d8b11a2b4fb3f6f8408a57190c6cd8b",
        "7fdf91f5c7a9247b53a6bbf267a6ce435d02afa47e5240698a12a7fa2058e060",
    },
    "sol-advisor-spark-worker.toml": {
        "36be86456404373582108586c80b0043ee03ea10b2336362a3c87148412603ca",
        "66f579e38f26252cd78bf123c8a7e3c0db3dd3e6bc63291e2e7d489b4518b68d",
        "afd61bc86e9721c40ff3951953202ac2b2348e2b58aefdb7d1093aae855668e6",
        "b9fdecbb1ba7b7072c759ca65546b108d69d7ad8f6a44321c4a25a46af8bb873",
    },
}


# Exact prior seven-role release, including both supported newline forms.
legacy_hashes.setdefault("sol-advisor-context-analyst.toml", set()).update(["c121da5fc937fa4a207990fbf8f9da2990279109610c9dc079a8f85e1eb867e6","9169c0e6766ba596684689e73f0e603aa59cc6820e6951e564b7d0cd23983d24"])
legacy_hashes.setdefault("sol-advisor-final-adjudicator.toml", set()).update(["fd978cb12f7fd3b2fbe1e695b2b6bc3583bb8736fd30033852ebcf1887e107ec","aa72b40add413846bb1b172c4f0fa898e73f741e90c6bebb53c5e0a92e1b87c4"])
legacy_hashes.setdefault("sol-advisor-investigator.toml", set()).update(["97a0881272315c37c4f279bd8a48f13a798734d03bd76c8599cedd0ea85abd2e","7787a072413a64ee8fa6354269fa9c0903043aa6d42085c3c568209e402a632e"])
legacy_hashes.setdefault("sol-advisor-local-code-verifier.toml", set()).update(["18910d6adc3e1a22b45daabc204484010bf410d4fe286ed9e9635784c3ba4eff","bcd0a9926297be4e484d0300b87c666dc2caac08746b3137ce0f0f4e08323769"])
legacy_hashes.setdefault("sol-advisor-mechanical-editor.toml", set()).update(["4d2a5a11e6677f0be83aa29464a0d6c91b4308471842c52faa328deb54073f07","51fff7da52f49c7e9c8f9c7ba2204befbfc871cb6160cdbce6e06a38983004e5"])
legacy_hashes.setdefault("sol-advisor-spark-worker.toml", set()).update(["afd61bc86e9721c40ff3951953202ac2b2348e2b58aefdb7d1093aae855668e6","b9fdecbb1ba7b7072c759ca65546b108d69d7ad8f6a44321c4a25a46af8bb873"])
legacy_hashes.setdefault("sol-advisor-test-executor.toml", set()).update(["7a9cc89bfb254f4ba881adc19fd5c384befbda96f5b9bd6fb6570d4db1a02cac","3b783e4a604e66fa6585d1e2322583fb3cecef281723554e01b0f420812dee9d"])
# Exact first five-role candidate, before the observed A/B coverage correction.
legacy_hashes.setdefault("sol-advisor-spark-worker.toml", set()).update(["c3d890994ba648ef4c92c935f675bf98983c3ae920737746e1bfd30534dd775b","9b59f0c075bbb4cefcb3d849b99c21e6715e19dcf70e436176c082026d9fc3c1"])
legacy_hashes.setdefault("sol-advisor-context-analyst.toml", set()).update(["b796c78132038b2968fb262859c39946a990d37b5295aa2d611fa82c2caa7f55","056e92bfaeea36a4fa0297ac9d9e19cc5b87846b4d563c9e8f78dd2b406662d6"])
retired_files = ("sol-advisor-investigator.toml", "sol-advisor-test-executor.toml")


def fail(message: str) -> None:
    raise RuntimeError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


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
template_line_ending_hashes: dict[str, set[str]] = {}
for name in agent_files:
    path = template_dir / name
    if not regular_file(path):
        fail(f"shipped template is missing or not a regular file: {path}")
    template_hashes[name] = sha256(path)
    normalized = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    template_line_ending_hashes[name] = {
        sha256_bytes(normalized),
        sha256_bytes(normalized.replace(b"\n", b"\r\n")),
    }

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
    elif mode == "upgrade-managed" and existing_hash in (
        legacy_hashes.get(name, set()) | template_line_ending_hashes[name]
    ):
        actions.append((name, "replace", existing_hash))
    else:
        errors.append(f"destination differs from a current or recognized managed template: {destination}")

for name in retired_files:
    destination = target_dir / name
    if not destination.exists() and not destination.is_symlink():
        continue
    if mode != "upgrade-managed" or not regular_file(destination):
        errors.append(f"retired agent requires managed upgrade: {destination}")
    elif sha256(destination) not in legacy_hashes.get(name, set()):
        errors.append(f"retired agent is user-modified and will be preserved: {destination}")
    else:
        actions.append((name, "remove", sha256(destination)))

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
        if action not in {"replace", "remove"}:
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
        elif action == "remove":
            if not regular_file(destination) or sha256(destination) != expected_hash:
                fail(f"retired destination changed after preflight: {destination}")
            destination.unlink()
            applied.append((name, action))
            messages.append(f"REMOVED RETIRED MANAGED: {destination}")
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
            elif action == "remove":
                if destination.exists() or destination.is_symlink():
                    rollback_errors.append(f"retired destination reappeared and was preserved: {destination}")
                else:
                    os.replace(backups[name], destination)
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
