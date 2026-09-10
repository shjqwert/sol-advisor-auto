#!/bin/sh
# No-cost repository-local verification for Sol Advisor.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

agent_files='sol-advisor-scout__gpt_5_6_luna.toml sol-advisor-worker__gpt_5_6_sol.toml sol-advisor-reviewer__gpt_5_6_sol.toml sol-advisor-reviewer__gpt_6_astra.toml'
legacy_agent_files='sol-advisor-investigator.toml sol-advisor-context-analyst.toml sol-advisor-mechanical-editor.toml sol-advisor-local-code-verifier.toml sol-advisor-final-adjudicator.toml'

hash_agents() {
  find "$1" -maxdepth 1 -type f -name 'sol-advisor-*.toml' -print |
    LC_ALL=C sort |
    while IFS= read -r agent_file; do sha256sum "$agent_file"; done |
    sha256sum | awk '{print $1}'
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
route_validator=$script_dir/validate-agent-route.sh
runtime_inspector=$script_dir/inspect-agent-runtime.sh
python_runner=$script_dir/run-python.sh
search_preflight=$script_dir/prepare-repo-search.py
templates=$plugin_dir/agents
legacy_templates=$script_dir/fixtures/agents-0.7.0
previous_templates=$script_dir/fixtures/agents-0.9.4
immediate_templates=$script_dir/fixtures/agents-0.10.2
current_templates=$script_dir/fixtures/agents-0.11.0
latest_templates=$script_dir/fixtures/agents-0.12.0
pre_astra_templates=$script_dir/fixtures/agents-1.0.0-pre-astra
manifest=$plugin_dir/.codex-plugin/plugin.json
mcp_config=$plugin_dir/.mcp.json
skill=$plugin_dir/skills/orchestration/SKILL.md
metadata=$plugin_dir/skills/orchestration/agents/openai.yaml
repo_root=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
readme=$repo_root/README.md
gitattributes=$repo_root/.gitattributes

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in /*) ;; *) tmp_base=/tmp ;; esac
tmp_dir=''

cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    case "$tmp_dir" in
      "$tmp_base"/sol-advisor-verify.*) rm -rf "$tmp_dir" ;;
      *) printf '%s\n' "REFUSING cleanup of unexpected directory: $tmp_dir" >&2 ;;
    esac
  fi
}
trap cleanup 0 HUP INT TERM

tmp_dir=$(mktemp -d "$tmp_base/sol-advisor-verify.XXXXXX") || fail "could not create disposable verification directory"
case "$tmp_dir" in "$tmp_base"/sol-advisor-verify.*) ;; *) fail "unexpected temporary directory: $tmp_dir" ;; esac

for required in "$installer" "$route_validator" "$runtime_inspector" "$python_runner" "$search_preflight" "$manifest" "$mcp_config" "$skill" "$metadata" "$readme" "$gitattributes"; do
  test -f "$required" || fail "required file missing: $required"
done
test -d "$legacy_templates" || fail "legacy managed-upgrade fixtures are missing"
test -d "$previous_templates" || fail "previous managed-upgrade fixtures are missing"
test -d "$latest_templates" || fail "latest managed-upgrade fixtures are missing"
test -d "$pre_astra_templates" || fail "pre-Astra 1.0.0 managed-upgrade fixtures are missing"

for retired in "$script_dir/validate-dispatch-plan.py" "$script_dir/validate-agent-result.py" "$script_dir/sol_advisor_paths.py"; do
  test ! -e "$retired" || fail "retired runtime protocol file remains: $retired"
done
pass "retired runtime dispatch, result, and state scripts remain absent"

for retired_writer in "$script_dir/install-global-trigger.sh" "$plugin_dir/templates/global-agents-block.md"; do
  test ! -e "$retired_writer" || fail "retired AGENTS.md writer remains: $retired_writer"
done
pass "Sol Advisor ships no user- or project-level AGENTS.md writer"

sh "$python_runner" "$script_dir/test_configuration.py"
sh "$python_runner" "$script_dir/test_installation.py"
sh "$python_runner" "$script_dir/test_snapshot.py"
pass "model-profile configuration, managed installation and snapshot regression"

clean_target=$tmp_dir/clean-install
sh "$installer" --target-dir "$clean_target" >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$clean_target/$agent_file" || fail "clean install differs: $agent_file"
done
installed_count=$(find "$clean_target" -maxdepth 1 -type f -name 'sol-advisor-*.toml' | awk 'END { print NR + 0 }')
[ "$installed_count" -eq 4 ] || fail "installer did not produce exactly four model profiles"

missing_check_target=$tmp_dir/missing-check
if sh "$installer" --target-dir "$missing_check_target" --check >/dev/null 2>&1; then fail "--check accepted missing target"; fi
test ! -e "$missing_check_target" || fail "--check mutated a missing target"

before_repeat=$(hash_agents "$clean_target")
sh "$installer" --target-dir "$clean_target" >/dev/null
sh "$installer" --target-dir "$clean_target" --check >/dev/null
after_repeat=$(hash_agents "$clean_target")
[ "$before_repeat" = "$after_repeat" ] || fail "repeat install/check changed files"

conflict_target=$tmp_dir/conflict
mkdir "$conflict_target"
printf '%s\n' conflict > "$conflict_target/sol-advisor-investigator.toml"
if sh "$installer" --target-dir "$conflict_target" >/dev/null 2>&1; then fail "installer overwrote a custom conflict"; fi
test ! -e "$conflict_target/sol-advisor-scout__gpt_5_6_luna.toml" || fail "conflict caused a partial install"
pass "clean four-profile install, exact check, idempotence, and conflict refusal"

line_ending_upgrade=$tmp_dir/current-crlf-upgrade
mkdir "$line_ending_upgrade"
sh "$python_runner" - "$templates" "$line_ending_upgrade" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])
for path in source.glob("*.toml"):
    data = path.read_bytes()
    if b"\r" in data:
        raise SystemExit(f"source template is not LF-only: {path}")
    (target / path.name).write_bytes(data.replace(b"\n", b"\r\n"))
PY
sh "$installer" --target-dir "$line_ending_upgrade" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$line_ending_upgrade" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$line_ending_upgrade/$agent_file" || fail "CRLF managed upgrade differs: $agent_file"
done
pass "current CRLF managed templates upgrade to exact LF release bytes"

upgrade_target=$tmp_dir/managed-upgrade
mkdir "$upgrade_target"
for agent_file in $legacy_agent_files; do cp "$legacy_templates/$agent_file" "$upgrade_target/$agent_file"; done
before_rollback=$(hash_agents "$upgrade_target")
if SOL_ADVISOR_INSTALL_TEST_FAIL_AFTER=4 sh "$installer" --target-dir "$upgrade_target" --upgrade-managed >/dev/null 2>&1; then
  fail "simulated managed-upgrade failure unexpectedly succeeded"
fi
after_rollback=$(hash_agents "$upgrade_target")
[ "$before_rollback" = "$after_rollback" ] || fail "managed-upgrade rollback changed legacy files"
test ! -e "$upgrade_target/sol-advisor-spark-worker.toml" || fail "managed-upgrade rollback left Spark installed"
test ! -e "$upgrade_target/sol-advisor-test-executor.toml" || fail "managed-upgrade rollback left Test Executor installed"
test "$(find "$upgrade_target" -maxdepth 1 -type d -name '.sol-advisor-agents.*' | awk 'END { print NR + 0 }')" -eq 0 || fail "managed-upgrade rollback left a transaction directory"

sh "$installer" --target-dir "$upgrade_target" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$upgrade_target" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$upgrade_target/$agent_file" || fail "managed upgrade differs: $agent_file"
done

upgrade_conflict=$tmp_dir/managed-conflict
mkdir "$upgrade_conflict"
for agent_file in $legacy_agent_files; do cp "$legacy_templates/$agent_file" "$upgrade_conflict/$agent_file"; done
printf '%s\n' '# user customization' >> "$upgrade_conflict/sol-advisor-investigator.toml"
before_conflict=$(hash_agents "$upgrade_conflict")
if sh "$installer" --target-dir "$upgrade_conflict" --upgrade-managed >/dev/null 2>&1; then
  fail "managed upgrade overwrote a customized legacy file"
fi
after_conflict=$(hash_agents "$upgrade_conflict")
[ "$before_conflict" = "$after_conflict" ] || fail "managed conflict caused partial replacement"
test ! -e "$upgrade_conflict/sol-advisor-spark-worker.toml" || fail "managed conflict caused partial Spark install"
test ! -e "$upgrade_conflict/sol-advisor-test-executor.toml" || fail "managed conflict caused partial Test Executor install"
pass "0.7 managed upgrade, exact-hash safety, rollback, and all-or-nothing conflict handling"

previous_upgrade=$tmp_dir/managed-upgrade-0.9.4
mkdir "$previous_upgrade"
for agent_file in $agent_files; do cp "$templates/$agent_file" "$previous_upgrade/$agent_file"; done
cp "$previous_templates/sol-advisor-mechanical-editor.toml" "$previous_upgrade/sol-advisor-mechanical-editor.toml"
cp "$previous_templates/sol-advisor-spark-worker.toml" "$previous_upgrade/sol-advisor-spark-worker.toml"
sh "$installer" --target-dir "$previous_upgrade" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$previous_upgrade" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$previous_upgrade/$agent_file" || fail "0.9.4 managed upgrade differs: $agent_file"
done
pass "0.9.4 managed Spark and Mechanical Editor upgrade"

immediate_upgrade=$tmp_dir/managed-upgrade-0.10.2
mkdir "$immediate_upgrade"
for agent_file in $agent_files; do
  cp "$templates/$agent_file" "$immediate_upgrade/$agent_file"
done
cp "$immediate_templates/sol-advisor-local-code-verifier.toml" "$immediate_upgrade/sol-advisor-local-code-verifier.toml"
sh "$installer" --target-dir "$immediate_upgrade" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$immediate_upgrade" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$immediate_upgrade/$agent_file" || fail "0.10.2 managed upgrade differs: $agent_file"
done
pass "0.10.2 managed Local Code Verifier upgrade"

current_upgrade=$tmp_dir/managed-upgrade-0.11.0
mkdir "$current_upgrade"
for agent_file in $agent_files; do cp "$templates/$agent_file" "$current_upgrade/$agent_file"; done
cp "$current_templates/sol-advisor-mechanical-editor.toml" "$current_upgrade/sol-advisor-mechanical-editor.toml"
cp "$current_templates/sol-advisor-final-adjudicator.toml" "$current_upgrade/sol-advisor-final-adjudicator.toml"
sh "$installer" --target-dir "$current_upgrade" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$current_upgrade" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$current_upgrade/$agent_file" || fail "0.11.0 managed upgrade differs: $agent_file"
done
pass "0.11.0 managed Mechanical Editor and Final Adjudicator upgrade"

latest_upgrade=$tmp_dir/managed-upgrade-0.12.0
mkdir "$latest_upgrade"
for agent_file in $agent_files; do cp "$templates/$agent_file" "$latest_upgrade/$agent_file"; done
cp "$latest_templates/sol-advisor-final-adjudicator.toml" "$latest_upgrade/sol-advisor-final-adjudicator.toml"
sh "$installer" --target-dir "$latest_upgrade" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$latest_upgrade" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$latest_upgrade/$agent_file" || fail "0.12.0 managed upgrade differs: $agent_file"
done
pass "0.12.0 managed Final Adjudicator upgrade"

pre_astra_upgrade=$tmp_dir/managed-upgrade-1.0.0-pre-astra
mkdir "$pre_astra_upgrade"
cp "$pre_astra_templates/sol-advisor-local-code-verifier.toml" "$pre_astra_upgrade/sol-advisor-local-code-verifier.toml"
cp "$pre_astra_templates/sol-advisor-final-adjudicator.toml" "$pre_astra_upgrade/sol-advisor-final-adjudicator.toml"
sh "$installer" --target-dir "$pre_astra_upgrade" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$pre_astra_upgrade" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$pre_astra_upgrade/$agent_file" || fail "pre-Astra 1.0.0 managed upgrade differs: $agent_file"
done
pass "pre-Astra 1.0.0 Local Code Verifier and Final Adjudicator managed upgrade"

index_target=$tmp_dir/index-plan
mkdir "$index_target"
git -C "$index_target" init -q
printf '%s\n' 'def example(): return 1' > "$index_target/example.py"
index_plan=$(sh "$python_runner" "$search_preflight" "$index_target" --indexing create-if-missing)
sh "$python_runner" - "$index_plan" "$index_target" <<'PY'
import json
from pathlib import Path
import sys

data = json.loads(sys.argv[1])
root = Path(sys.argv[2])
if not data.get("valid") or data.get("applied"):
    raise SystemExit("index preflight plan was not read-only and valid")
if {item.get("tool") for item in data.get("operations", [])} != {"codegraph", "serena"}:
    raise SystemExit("index preflight did not probe CodeGraph and Serena")
if (root / ".codegraph").exists() or (root / ".serena").exists():
    raise SystemExit("plan-only index preflight created metadata")
PY
index_never=$(sh "$python_runner" "$search_preflight" "$index_target" --indexing never --apply)
sh "$python_runner" - "$index_never" <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
if not data.get("valid") or not data.get("applied"):
    raise SystemExit("never-index apply mode was not a safe no-op")
if any(item.get("status") != "skipped" for item in data.get("operations", [])):
    raise SystemExit("never-index policy planned an operation")
PY
sh "$python_runner" - "$search_preflight" "$index_target" <<'PY'
import os
from pathlib import Path
import runpy
import sys
import tempfile
from unittest.mock import patch

module = runpy.run_path(sys.argv[1])
snapshot = module["workspace_change_snapshot"]
snapshot_error = module["SnapshotError"]
detect_workspace_kind = module["detect_workspace_kind"]
root = Path(sys.argv[2])

paths, first = snapshot(root, "git")
if "example.py" not in paths:
    raise SystemExit("Git snapshot omitted an untracked protected file")
metadata = (root / "example.py").stat()
(root / "example.py").write_text("def example(): return 2\n", encoding="utf-8")
os.utime(root / "example.py", ns=(metadata.st_atime_ns, metadata.st_mtime_ns))
_, second = snapshot(root, "git")
if first == second:
    raise SystemExit("Git snapshot missed a same-size content change")

(root / "new.txt").write_text("new", encoding="utf-8")
paths, third = snapshot(root, "git")
if "new.txt" not in paths or third == second:
    raise SystemExit("Git snapshot missed an untracked creation")
(root / "new.txt").unlink()
_, fourth = snapshot(root, "git")
if fourth == third:
    raise SystemExit("Git snapshot missed an untracked deletion")

(root / ".codegraph").mkdir()
(root / ".codegraph" / "generated.db").write_text("ignored", encoding="utf-8")
paths, _ = snapshot(root, "git")
if any(value.startswith(".codegraph/") for value in paths):
    raise SystemExit("Git snapshot included an explicitly generated directory")

import subprocess

with patch.dict(
    detect_workspace_kind.__globals__,
    {"run": lambda command, **kwargs: subprocess.CompletedProcess(command, 127, "", "git unavailable")},
):
    if detect_workspace_kind(root) != "git":
        raise SystemExit("a failed Git check was silently reclassified as a plain directory")

with patch.dict(
    snapshot.__globals__,
    {"run": lambda command, **kwargs: subprocess.CompletedProcess(command, 2, "", "denied")},
):
    try:
        snapshot(root, "git")
    except snapshot_error:
        pass
    else:
        raise SystemExit("Git enumeration failure was treated as an unchanged workspace")

try:
    with patch.object(Path, "open", side_effect=PermissionError("denied")):
        snapshot(root, "git")
except snapshot_error:
    pass
else:
    raise SystemExit("protected-file read failure was treated as unchanged")
PY
pass "portable Python runner, repository index preflight, and content-based read-only snapshot"

runtime_sessions=$tmp_dir/runtime-sessions
runtime_day=$runtime_sessions/2026/08/16
mkdir -p "$runtime_day"
stable_id=11111111-1111-7111-8111-111111111111
stable_rollout=$runtime_day/rollout-2026-08-16T00-00-00-$stable_id.jsonl
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$stable_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_context_analyst\",\"agent_path\":\"/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture/cwd\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"xhigh","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture/cwd"}}' \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"xhigh","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture/cwd"}}' \
  > "$stable_rollout"
runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$stable_id")
sh "$python_runner" - "$runtime_output" <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
expected = {
    "agent_role": "sol_advisor_context_analyst",
    "model_provider": "openai",
    "model": "gpt-5.6-terra",
    "effort": "xhigh",
}
if any(data.get(key) != value for key, value in expected.items()):
    raise SystemExit("runtime inspector returned an unexpected stable route")
PY
printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK && fail "runtime inspector leaked prompt content"

mixed_effort_id=22222222-2222-7222-8222-222222222222
mixed_effort_rollout=$runtime_day/rollout-2026-08-16T00-00-01-$mixed_effort_id.jsonl
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$mixed_effort_id\",\"agent_role\":\"sol_advisor_context_analyst\",\"model_provider\":\"openai\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"xhigh","cwd":"/fixture/cwd"}}' \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"max","cwd":"/fixture/cwd"}}' \
  > "$mixed_effort_rollout"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$mixed_effort_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted a mid-child effort change"
fi

mixed_model_id=33333333-3333-7333-8333-333333333333
mixed_model_rollout=$runtime_day/rollout-2026-08-16T00-00-02-$mixed_model_id.jsonl
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$mixed_model_id\",\"agent_role\":\"sol_advisor_local_code_verifier\",\"model_provider\":\"openai\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"xhigh","cwd":"/fixture/cwd"}}' \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-sol","effort":"xhigh","cwd":"/fixture/cwd"}}' \
  > "$mixed_model_rollout"
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$mixed_model_id" >/dev/null 2>&1; then
  fail "runtime inspector accepted a mid-child model change"
fi
pass "stable multi-turn configuration and mixed model/effort rejection without prompt leakage"


sh "$python_runner" - "$search_preflight" <<'PY'
import ast
from pathlib import Path
import sys
ast.parse(Path(sys.argv[1]).read_text(encoding="utf-8"))
PY

sh -n "$installer"
sh -n "$route_validator"
sh -n "$runtime_inspector"
sh -n "$python_runner"
sh -n "$script_dir/verify.sh"
for shell_file in "$installer" "$route_validator" "$runtime_inspector" "$python_runner" "$script_dir/verify.sh"; do
  if grep -q "$(printf '\r')" "$shell_file"; then fail "CRLF remains in shell script: $shell_file"; fi
done
grep -Fq '*.sh text eol=lf' "$gitattributes" || fail "repository does not enforce LF for shell scripts"
[ "$(wc -l < "$skill")" -lt 100 ] || fail "orchestration Skill exceeds the progressive-disclosure line budget"
pass "static Python checks, shell syntax and LF policy"

printf '%s\n' "VERIFY PASSED: Sol Advisor 2.0.0 local checks completed in $tmp_dir"
