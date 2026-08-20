#!/bin/sh
# No-cost repository-local verification for Sol Advisor.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

agent_files='sol-advisor-investigator.toml sol-advisor-context-analyst.toml sol-advisor-mechanical-editor.toml sol-advisor-test-executor.toml sol-advisor-local-code-verifier.toml sol-advisor-final-adjudicator.toml sol-advisor-spark-worker.toml'
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
manifest=$plugin_dir/.codex-plugin/plugin.json
mcp_config=$plugin_dir/.mcp.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
contract_dir=$plugin_dir/skills/orchestration/references/roles
investigator_contract=$contract_dir/investigator.md
context_contract=$contract_dir/context-analyst.md
mechanical_contract=$contract_dir/mechanical-editor.md
test_executor_contract=$contract_dir/test-executor.md
verifier_contract=$contract_dir/local-code-verifier.md
adjudicator_contract=$contract_dir/final-adjudicator.md
spark_contract=$contract_dir/spark-worker.md
role_contract_files="$investigator_contract $context_contract $mechanical_contract $test_executor_contract $verifier_contract $adjudicator_contract $spark_contract"
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

for required in "$installer" "$route_validator" "$runtime_inspector" "$python_runner" "$search_preflight" "$manifest" "$mcp_config" "$skill" "$contracts" $role_contract_files "$metadata" "$readme" "$gitattributes"; do
  test -f "$required" || fail "required file missing: $required"
done
test -d "$legacy_templates" || fail "legacy managed-upgrade fixtures are missing"
test -d "$previous_templates" || fail "previous managed-upgrade fixtures are missing"

for retired in "$script_dir/validate-dispatch-plan.py" "$script_dir/validate-agent-result.py" "$script_dir/sol_advisor_paths.py"; do
  test ! -e "$retired" || fail "retired runtime protocol file remains: $retired"
done
pass "retired runtime dispatch, result, and state scripts remain absent"

for retired_writer in "$script_dir/install-global-trigger.sh" "$plugin_dir/templates/global-agents-block.md"; do
  test ! -e "$retired_writer" || fail "retired AGENTS.md writer remains: $retired_writer"
done
pass "Sol Advisor ships no user- or project-level AGENTS.md writer"

sh "$python_runner" - "$manifest" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not manifest.get("version", "").startswith("0.11.0+"):
    raise SystemExit("manifest version was not advanced to 0.11.0")
expected = {
    "author": {"name": "shjqwert", "url": "https://github.com/shjqwert"},
    "homepage": "https://github.com/shjqwert/sol-advisor-auto#readme",
    "repository": "https://github.com/shjqwert/sol-advisor-auto",
}
for field, value in expected.items():
    if manifest.get(field) != value:
        raise SystemExit(f"manifest {field} does not identify the standalone repository")
if manifest.get("mcpServers") != "./.mcp.json":
    raise SystemExit("manifest does not declare the MCP companion")
interface = manifest.get("interface", {})
if not interface.get("displayName") or not interface.get("defaultPrompt"):
    raise SystemExit("existing plugin interface was removed")
if len(interface.get("defaultPrompt", [])) > 3:
    raise SystemExit("manifest declares more than the three default prompts accepted by Codex")
for index, prompt in enumerate(interface.get("defaultPrompt", [])):
    if len(prompt) > 128:
        raise SystemExit(f"manifest defaultPrompt[{index}] exceeds the Codex 128-character limit: {len(prompt)}")
prompts = " ".join(interface.get("defaultPrompt", [])).lower()
for required in ("accuracy", "first-pass completion", "expected total workflow cost", "one native final result"):
    if required not in prompts:
        raise SystemExit(f"manifest prompts do not describe the 0.9 routing goals: {required}")
for required in ("consider a bounded child", "use zero children"):
    if required not in prompts:
        raise SystemExit(f"manifest prompts do not describe optional delegation: {required}")
if "check cheap hard prerequisites" in prompts:
    raise SystemExit("manifest still mandates a phase preflight")
PY
pass "plugin manifest version, ownership, three-prompt interface limits, and 0.11.0 routing metadata"

sh "$python_runner" - "$mcp_config" <<'PY'
import json
from pathlib import Path
import sys

servers = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("mcpServers", {})
expected = {
    "context7": ("http", "https://mcp.context7.com/mcp"),
    "exa": ("http", "https://mcp.exa.ai/mcp"),
}
for name, (kind, url) in expected.items():
    value = servers.get(name, {})
    if value.get("type") != kind or value.get("url") != url:
        raise SystemExit(f"unexpected {name} MCP endpoint")
markitdown = servers.get("markitdown", {})
if markitdown.get("command") != "uvx" or markitdown.get("args") != ["markitdown-mcp"]:
    raise SystemExit("unexpected MarkItDown MCP command")
if set(servers) != {"context7", "exa", "markitdown"}:
    raise SystemExit("unexpected MCP set")
PY
pass "existing Context7, Exa, and MarkItDown MCP configuration"

sh "$python_runner" - "$templates" "$legacy_templates" "$previous_templates" "$immediate_templates" <<'PY'
from pathlib import Path
import sys
import tomllib

templates = Path(sys.argv[1])
legacy_templates = Path(sys.argv[2])
previous_templates = Path(sys.argv[3])
immediate_templates = Path(sys.argv[4])
roles = {
    "sol-advisor-investigator.toml": ("sol_advisor_investigator", "gpt-5.6-luna"),
    "sol-advisor-context-analyst.toml": ("sol_advisor_context_analyst", None),
    "sol-advisor-mechanical-editor.toml": ("sol_advisor_mechanical_editor", "gpt-5.6-luna"),
    "sol-advisor-test-executor.toml": ("sol_advisor_test_executor", "gpt-5.6-luna"),
    "sol-advisor-local-code-verifier.toml": ("sol_advisor_local_code_verifier", None),
    "sol-advisor-final-adjudicator.toml": ("sol_advisor_final_adjudicator", "gpt-5.6-sol"),
    "sol-advisor-spark-worker.toml": ("sol_advisor_spark_worker", "gpt-5.3-codex-spark"),
}
actual = {path.name for path in templates.glob("*.toml")}
if actual != set(roles):
    raise SystemExit(f"unexpected custom-agent templates: {sorted(actual ^ set(roles))}")

common_required = (
    "applicable agents.md",
    "inherited mcp and skill",
    "do not create or manage other agents",
    "ordinary final response",
    "end the turn immediately",
    "complete",
    "incomplete",
    "blocked",
    "parent-interaction messaging",
)
universal_retired = (
    "return_mode",
    "task_understanding",
    "answer/verdict",
    "decision-changing findings",
)
role_required = {
    "sol-advisor-investigator.toml": ("search_scope", "version_date_boundary", "medium for straightforward", "high for cross-module", "answer", "evidence", "600-1400"),
    "sol-advisor-context-analyst.toml": ("sources", "synthesis_required", "source_locators", "medium for straightforward", "terra at high", "900-2200"),
    "sol-advisor-mechanical-editor.toml": ("owned_files", "repetition_scope", "high for routine", "boundary-heavy", "changed_files", "500-1200"),
    "sol-advisor-test-executor.toml": ("plan_id", "authorized_side_effects", "evidence_output", "xhigh for a difficult", "max only", "next_action", "repair_resume", "new_child", "primary_decision", "resume_point", "900-2200"),
    "sol-advisor-local-code-verifier.toml": ("attack_angle", "pass_fail_criteria", "ordered test plan", "plan_id", "resume_point", "medium for routine", "high for multiple", "gpt-5.6-sol", "test_gaps", "700-1800"),
    "sol-advisor-final-adjudicator.toml": ("conflicting_claims", "evidence_locators", "ship", "fix_first", "rethink", "700-1600"),
    "sol-advisor-spark-worker.toml": ("mode: produce", "goal", "owned_files", "input_facts", "reference_locators", "acceptance", "preserve", "check", "done_when", "stop", "unverified", "400-900"),
}

for filename, (name, model) in roles.items():
    path = templates / filename
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    if data.get("name") != name or data.get("model_provider") != "openai":
        raise SystemExit(f"{path}: unexpected role or provider")
    if model is None:
        if "model" in data:
            raise SystemExit(f"{path}: dynamic role unexpectedly pins a model")
    elif data.get("model") != model:
        raise SystemExit(f"{path}: unexpected pinned model")
    for forbidden in ("model_reasoning_effort", "sandbox_mode", "mcp_servers", "skills", "web_search", "shell_environment_policy"):
        if forbidden in data:
            raise SystemExit(f"{path}: inherited capability or effort was overridden by {forbidden}")
    if data.get("features", {}).get("multi_agent") is not False:
        raise SystemExit(f"{path}: descendant agents are not disabled")
    instructions = " ".join(data.get("developer_instructions", "").split()).lower()
    for required in common_required + role_required[filename]:
        if required not in instructions:
            raise SystemExit(f"{path}: missing prompt contract: {required}")
    for forbidden in universal_retired:
        if forbidden in instructions:
            raise SystemExit(f"{path}: retired universal result field remains: {forbidden}")
    for forbidden in ("result path", "sidecar", "state.json", "pending record", "response token"):
        if forbidden in instructions:
            raise SystemExit(f"{path}: retired runtime protocol remains: {forbidden}")

legacy = {path.name for path in legacy_templates.glob("*.toml")}
if legacy != set(roles) - {"sol-advisor-spark-worker.toml", "sol-advisor-test-executor.toml"}:
    raise SystemExit("legacy upgrade fixture set is incomplete")
for path in legacy_templates.glob("*.toml"):
    tomllib.loads(path.read_text(encoding="utf-8"))
previous = {path.name for path in previous_templates.glob("*.toml")}
if previous != {"sol-advisor-mechanical-editor.toml", "sol-advisor-spark-worker.toml"}:
    raise SystemExit("0.9.4 managed-upgrade fixture set is incomplete")
for path in previous_templates.glob("*.toml"):
    tomllib.loads(path.read_text(encoding="utf-8"))
immediate = {path.name for path in immediate_templates.glob("*.toml")}
if immediate != {"sol-advisor-local-code-verifier.toml"}:
    raise SystemExit("0.10.2 managed-upgrade fixture set is incomplete")
for path in immediate_templates.glob("*.toml"):
    tomllib.loads(path.read_text(encoding="utf-8"))
PY
pass "seven role configurations, cost-aware effort profiles, specialized prompts, and managed fixtures"

valid_routes='sol_advisor_spark_worker openai gpt-5.3-codex-spark low
sol_advisor_spark_worker openai gpt-5.3-codex-spark medium
sol_advisor_spark_worker openai gpt-5.3-codex-spark high
sol_advisor_investigator openai gpt-5.6-luna medium
sol_advisor_investigator openai gpt-5.6-luna high
sol_advisor_investigator openai gpt-5.6-luna xhigh
sol_advisor_investigator openai gpt-5.6-luna max
sol_advisor_context_analyst openai gpt-5.6-luna medium
sol_advisor_context_analyst openai gpt-5.6-luna high
sol_advisor_context_analyst openai gpt-5.6-terra high
sol_advisor_context_analyst openai gpt-5.6-terra xhigh
sol_advisor_context_analyst openai gpt-5.6-terra max
sol_advisor_mechanical_editor openai gpt-5.6-luna high
sol_advisor_mechanical_editor openai gpt-5.6-luna xhigh
sol_advisor_mechanical_editor openai gpt-5.6-luna max
sol_advisor_test_executor openai gpt-5.6-luna xhigh
sol_advisor_test_executor openai gpt-5.6-luna max
sol_advisor_local_code_verifier openai gpt-5.6-luna medium
sol_advisor_local_code_verifier openai gpt-5.6-luna high
sol_advisor_local_code_verifier openai gpt-5.6-luna xhigh
sol_advisor_local_code_verifier openai gpt-5.6-luna max
sol_advisor_local_code_verifier openai gpt-5.6-sol xhigh
sol_advisor_local_code_verifier openai gpt-5.6-sol max
sol_advisor_final_adjudicator openai gpt-5.6-sol xhigh
sol_advisor_final_adjudicator openai gpt-5.6-sol max'
printf '%s\n' "$valid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null || fail "documented route rejected: $role $provider $model $effort"
done

invalid_routes='sol_advisor_spark_worker openai gpt-5.3-codex-spark xhigh
sol_advisor_investigator openai gpt-5.6-luna low
sol_advisor_context_analyst openai gpt-5.6-luna xhigh
sol_advisor_context_analyst openai gpt-5.6-luna max
sol_advisor_context_analyst openai gpt-5.6-terra medium
sol_advisor_mechanical_editor openai gpt-5.6-luna medium
sol_advisor_mechanical_editor openai gpt-5.6-terra max
sol_advisor_test_executor openai gpt-5.6-luna high
sol_advisor_test_executor openai gpt-5.6-sol max
sol_advisor_local_code_verifier openai gpt-5.6-sol medium
sol_advisor_local_code_verifier openai gpt-5.6-sol high
sol_advisor_local_code_verifier openai gpt-5.6-terra max
sol_advisor_final_adjudicator openai gpt-5.6-sol medium
sol_advisor_final_adjudicator openai gpt-5.6-sol ultra'
printf '%s\n' "$invalid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  if sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null 2>&1; then
    fail "undocumented route accepted: $role $provider $model $effort"
  fi
done
pass "quality-gated cost-aware route matrix and invalid-route rejection"

clean_target=$tmp_dir/clean-install
sh "$installer" --target-dir "$clean_target" >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$clean_target/$agent_file" || fail "clean install differs: $agent_file"
done
installed_count=$(find "$clean_target" -maxdepth 1 -type f -name 'sol-advisor-*.toml' | awk 'END { print NR + 0 }')
[ "$installed_count" -eq 7 ] || fail "installer did not produce exactly seven roles"

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
test ! -e "$conflict_target/sol-advisor-spark-worker.toml" || fail "conflict caused a partial install"
pass "clean seven-role install, exact check, idempotence, and conflict refusal"

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
  [ "$agent_file" = sol-advisor-test-executor.toml ] || cp "$templates/$agent_file" "$immediate_upgrade/$agent_file"
done
cp "$immediate_templates/sol-advisor-local-code-verifier.toml" "$immediate_upgrade/sol-advisor-local-code-verifier.toml"
sh "$installer" --target-dir "$immediate_upgrade" --upgrade-managed >/dev/null
sh "$installer" --target-dir "$immediate_upgrade" --check >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$immediate_upgrade/$agent_file" || fail "0.10.2 managed upgrade differs: $agent_file"
done
pass "0.10.2 managed Local Code Verifier upgrade and Test Executor install"

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
pass "portable Python runner and repository index preflight"

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

for document in "$skill" "$contracts" "$readme"; do
  for role in sol_advisor_investigator sol_advisor_context_analyst sol_advisor_mechanical_editor sol_advisor_test_executor sol_advisor_local_code_verifier sol_advisor_final_adjudicator sol_advisor_spark_worker; do
    grep -Fq "$role" "$document" || fail "missing role $role in $document"
  done
  grep -Fq 'AGENTS.md' "$document" || fail "missing project-rule inheritance: $document"
  grep -Fqi 'one corrective' "$document" || grep -Fqi 'one targeted follow-up' "$document" || fail "missing bounded correction rule: $document"
  grep -Fqi 'final response' "$document" || fail "missing native final-response lifecycle: $document"
  grep -Fqi 'parent-interaction' "$document" || fail "missing interaction-message prohibition: $document"
done

grep -Fq 'fork_turns: "none"' "$skill" || fail "missing isolated child spawn rule"
grep -Fq 'Pass both the exact `model`' "$skill" || fail "missing explicit dynamic model and effort rule"
grep -Fq 'expected total workflow cost' "$skill" || fail "missing complete-workflow cost objective"
grep -Fq 'task accuracy and first-pass completion as hard gates' "$skill" || fail "missing quality hard gate"
grep -Fq 'Do not infer ChatGPT subscription credit multipliers' "$skill" || fail "missing subscription-pricing evidence boundary"
grep -Fq 'available capacity, not a target to fill' "$skill" || fail "missing large-context capacity boundary"
grep -Fq 'Keep complex implementation primary' "$skill" || fail "missing complex implementation boundary"
grep -Fq 'Development-time static validation' "$skill" || fail "missing static Python-validation allowance"
grep -Fq 'allow_implicit_invocation: true' "$metadata" || fail "automatic invocation policy missing"
grep -Fq 'globally allowed' "$skill" || fail "missing global implicit route-evaluation default"
grep -Fq 'Do not require a project `.agent` directory' "$skill" || fail "missing no-project-bootstrap rule"
grep -Fq 'empty folders' "$skill" || fail "missing empty-folder automatic-evaluation scope"
grep -Fq 'non-Git directories' "$skill" || fail "missing non-Git automatic-evaluation scope"
grep -Fq 'from-scratch' "$skill" || fail "missing from-scratch automatic-evaluation scope"
grep -Fq 'authorizations.solAdvisor.implicitDelegation` exactly `false`' "$skill" || fail "missing project opt-out value"
grep -Fq 'Exact `true`, a missing file,' "$skill" || fail "missing default-allow compatibility rule"
grep -Fq 'or a missing key leaves the global default enabled' "$skill" || fail "missing default-allow compatibility rule"
grep -Fq 'agents.enabled = false' "$skill" || fail "missing Codex multi-agent hard-disable rule"
grep -Fq 'invalid or unreadable' "$skill" || fail "missing invalid-override fail-safe rule"
if grep -Fq 'spawn no child unless both signals are present' "$skill"; then fail "retired dual authorization gate remains"; fi
if grep -Fq 'matching `## Subagent Orchestration` authorization instruction' "$skill"; then fail "retired managed AGENTS authorization gate remains"; fi
grep -Fq 'instruction not to' "$skill" || fail "missing explicit no-delegation override"
grep -Fq 'Use zero children' "$skill" || fail "missing zero-child fast path"
grep -Fq 'at most two concurrent children' "$skill" || fail "missing two-child read-only cap"
grep -Fq 'Do not use Final Adjudicator as' "$skill" || fail "missing fixed-chain prevention"
grep -Fq 'frozen ordered test plan' "$skill" || fail "quality gate lacks the Test Executor work type"
grep -Fq 'Test Executor and Local Code Verifier are mutually exclusive' "$skill" || fail "missing Test Executor and verifier role boundary"
grep -Fq 'Test Executor has one role-specific lifecycle exception' "$skill" || fail "missing Test Executor resume exception"
grep -Fq 'repair-resume turns do not consume the one corrective follow-up' "$skill" || fail "Test Executor resume consumes the corrective retry"
grep -Fq 'Test Executor is the only resumable role' "$contracts" || fail "common contract lacks the resumable-role boundary"
grep -Fq 'A new full run or material plan/scope change requires a new child' "$contracts" || fail "common contract lacks the new-run boundary"
grep -Fq '`NEXT_ACTION` must be exactly `REPAIR_RESUME`, `NEW_CHILD`, or `PRIMARY_DECISION`' "$test_executor_contract" || fail "Test Executor contract lacks the blocked-action discriminant"
grep -Fq 'Required only when `NEXT_ACTION: REPAIR_RESUME`' "$test_executor_contract" || fail "Test Executor resume fields are not conditional"
grep -Fq 'must not execute a whole' "$verifier_contract" || fail "verifier contract can own a whole ordered plan"
contract_count=$(find "$contract_dir" -maxdepth 1 -type f -name '*.md' | awk 'END { print NR + 0 }')
[ "$contract_count" -eq 7 ] || fail "progressive role-contract set must contain exactly seven files"
for mapping in \
  'sol_advisor_investigator:roles/investigator.md' \
  'sol_advisor_context_analyst:roles/context-analyst.md' \
  'sol_advisor_mechanical_editor:roles/mechanical-editor.md' \
  'sol_advisor_test_executor:roles/test-executor.md' \
  'sol_advisor_local_code_verifier:roles/local-code-verifier.md' \
  'sol_advisor_final_adjudicator:roles/final-adjudicator.md' \
  'sol_advisor_spark_worker:roles/spark-worker.md'; do
  role=${mapping%%:*}
  path=${mapping#*:}
  grep -Fq "\`$role\`" "$contracts" || fail "contract index lacks role: $role"
  grep -Fq "($path)" "$contracts" || fail "contract index lacks selected role path: $path"
done
grep -Fq 'load exactly one selected file' "$skill" || fail "Skill lacks selected-only contract loading"
grep -Fq 'do not load the other role files' "$contracts" || fail "contract index lacks progressive-disclosure boundary"
for contract in $role_contract_files; do
  grep -Fq 'Required final fields' "$contract" || fail "missing required fields in $contract"
  [ "$(wc -l < "$contract")" -lt 80 ] || fail "selected role contract is too large: $contract"
done
for contract in "$investigator_contract" "$context_contract" "$mechanical_contract" "$test_executor_contract" "$verifier_contract" "$spark_contract"; do
  grep -Fq 'Optional when nonempty' "$contract" || fail "missing optional-field rule in $contract"
done
if grep -Fq 'install-global-trigger.sh' "$readme"; then fail "README still installs a global AGENTS.md writer"; fi
grep -Fq 'never writes user- or project-level `AGENTS.md`' "$readme" || fail "README lacks the AGENTS.md ownership boundary"
grep -Fq 'Never create, modify, or remove a user-' "$skill" || fail "Skill lacks the no-AGENTS-writer boundary"
grep -Fq 'Global eligibility permits automatic' "$skill" || fail "missing eligibility-not-obligation rule"
grep -Fq 'optional context hygiene, not a fixed' "$skill" || fail "missing optional-preflight boundary"
grep -Fq 'Do not require the primary to report or persist' "$skill" || fail "missing no-route-record rule"
grep -Fq 'Children do not communicate directly' "$skill" || fail "missing child-communication boundary"
grep -Fq 'Do not route such bounded direct lookups' "$skill" || fail "missing primary direct-tool boundary"
grep -Fq 'Optional context preflight' "$readme" || fail "README lacks optional preflight guidance"
grep -Fq 'Use $orchestration for engineering work' "$metadata" || fail "Skill metadata lacks engineering-work invocation wording"
grep -Fq 'otherwise use zero children' "$metadata" || fail "Skill metadata lacks zero-child default"
if grep -Fq 'cheap hard prerequisites before loading phase-specific' "$metadata"; then fail "Skill metadata still mandates phase preflight"; fi

for active in "$skill" "$contracts" $role_contract_files "$readme" "$templates/sol-advisor-spark-worker.toml" "$templates/sol-advisor-mechanical-editor.toml"; do
  for retired_route in 'MODE: SCOUT' 'MODE: EDIT' EDIT_POINT_COUNT 'at most three files' nineteen 'at least four files' 'twenty same-type'; do
    if grep -Fq "$retired_route" "$active"; then fail "retired count-based Spark or Mechanical route remains in $active: $retired_route"; fi
  done
done
grep -Fq 'MODE: PRODUCE' "$skill" || fail "Skill lacks Spark PRODUCE route"
grep -Fq 'MODE: PRODUCE' "$spark_contract" || fail "Spark contract lacks PRODUCE mode"
grep -Fq 'MODE: PRODUCE' "$templates/sol-advisor-spark-worker.toml" || fail "Spark prompt lacks PRODUCE mode"
grep -Fq 'REPETITION_SCOPE' "$mechanical_contract" || fail "Mechanical Editor contract lacks nature-based repetition scope"
grep -Fq 'REPETITION_SCOPE' "$templates/sol-advisor-mechanical-editor.toml" || fail "Mechanical Editor prompt lacks nature-based repetition scope"

sh "$python_runner" - "$skill" <<'PY'
from pathlib import Path
import re
import sys

skill = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.match(r'^---\n.*?^description: "([^"]+)"\n---\n', skill, re.MULTILINE | re.DOTALL)
if not match:
    raise SystemExit("could not parse Skill frontmatter description")
description = match.group(1)
front = description.lower()
if len(description) > 240:
    raise SystemExit(f"frontmatter description exceeds the 240-character catalog budget: {len(description)}")
for phrase in (
    "use for engineering work",
    "long sources",
    "unknown search",
    "focused production",
    "repeated edits",
    "independent review",
    "decide whether bounded delegation",
    "preserves quality",
    "lowers total workflow cost",
    "zero children is valid",
):
    if phrase not in front:
        raise SystemExit(f"compact optional trigger guidance is missing: {phrase}")
scenario_specific = ("p" + "df", "note" + "booklm", "ch" + "ip")
for phrase in (
    "must delegate",
    "always delegate",
    "evaluate sol advisor before",
    "empty folders",
    "non-git",
    "from-scratch",
    *scenario_specific,
):
    if phrase in front:
        raise SystemExit(f"frontmatter contains a forced or scenario-specific trigger: {phrase}")
PY

for document in "$skill" "$contracts" $role_contract_files "$readme"; do
  for retired_field in RETURN_MODE TASK_UNDERSTANDING 'ANSWER/VERDICT' 'DECISION-CHANGING FINDINGS'; do
    if grep -Fq "$retired_field" "$document"; then fail "retired universal field remains in $document: $retired_field"; fi
  done
done
for agent_file in $agent_files; do
  for retired_field in RETURN_MODE TASK_UNDERSTANDING 'ANSWER/VERDICT' 'DECISION-CHANGING FINDINGS'; do
    if grep -Fq "$retired_field" "$templates/$agent_file"; then fail "retired universal field remains in $agent_file: $retired_field"; fi
  done
done
pass "quality and total-cost gates, progressive contracts, stable spawn configuration, and native lifecycle documentation"

deprecated_tool=$(printf '%s%s' 'Notebook' 'LM')
if grep -R -Fiq --exclude-dir='fixtures' --exclude-dir='__pycache__' "$deprecated_tool" "$plugin_dir" "$readme"; then
  fail "tool-specific trigger remains in active plugin content: $deprecated_tool"
fi
pass "trigger policy remains tool-neutral"

for retired_text in 'validate-dispatch-plan.py' 'validate-agent-result.py' 'sol_advisor_paths.py' 'RESULT PATH' 'RESPONSE TOKEN' 'pending_batch' '.sol-advisor/runs' '<git-dir>/sol-advisor/runs'; do
  if grep -R -Fq --exclude='verify.sh' --exclude-dir='fixtures' --exclude-dir='__pycache__' "$retired_text" "$plugin_dir" "$readme"; then
    fail "retired runtime protocol reference remains: $retired_text"
  fi
done
pass "no runtime Python result gate, retry state, or sidecar protocol"

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
[ "$(wc -l < "$skill")" -lt 500 ] || fail "orchestration Skill exceeds the progressive-disclosure line budget"
index_chars=$(wc -c < "$contracts")
[ "$index_chars" -lt 4000 ] || fail "common contract index exceeds the progressive-disclosure budget"
pass "static Python checks, shell syntax, LF policy, Skill budget, and contract-index budget"

printf '%s\n' "VERIFY PASSED: Sol Advisor 0.11.0 no-cost checks completed in $tmp_dir"
