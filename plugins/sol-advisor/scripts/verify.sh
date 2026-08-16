#!/bin/sh
# No-cost repository-local verification for Sol Advisor.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

agent_files='sol-advisor-investigator.toml sol-advisor-context-analyst.toml sol-advisor-mechanical-editor.toml sol-advisor-local-code-verifier.toml sol-advisor-final-adjudicator.toml sol-advisor-spark-worker.toml'
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
manifest=$plugin_dir/.codex-plugin/plugin.json
mcp_config=$plugin_dir/.mcp.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
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

for required in "$installer" "$route_validator" "$runtime_inspector" "$python_runner" "$search_preflight" "$manifest" "$mcp_config" "$skill" "$contracts" "$metadata" "$readme" "$gitattributes"; do
  test -f "$required" || fail "required file missing: $required"
done
test -d "$legacy_templates" || fail "legacy managed-upgrade fixtures are missing"

for retired in "$script_dir/validate-dispatch-plan.py" "$script_dir/validate-agent-result.py" "$script_dir/sol_advisor_paths.py"; do
  test ! -e "$retired" || fail "retired runtime protocol file remains: $retired"
done
pass "retired runtime dispatch, result, and state scripts remain absent"

sh "$python_runner" - "$manifest" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not manifest.get("version", "").startswith("0.8.0+"):
    raise SystemExit("manifest version was not advanced to 0.8.0")
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
prompts = " ".join(interface.get("defaultPrompt", [])).lower()
for required in ("accuracy", "primary-context", "weighted quota", "one native final result"):
    if required not in prompts:
        raise SystemExit(f"manifest prompts do not describe the 0.8 routing goals: {required}")
PY
pass "plugin manifest version, ownership, interface, and 0.8 routing metadata"

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

sh "$python_runner" - "$templates" "$legacy_templates" <<'PY'
from pathlib import Path
import sys
import tomllib

templates = Path(sys.argv[1])
legacy_templates = Path(sys.argv[2])
roles = {
    "sol-advisor-investigator.toml": ("sol_advisor_investigator", "gpt-5.6-luna"),
    "sol-advisor-context-analyst.toml": ("sol_advisor_context_analyst", None),
    "sol-advisor-mechanical-editor.toml": ("sol_advisor_mechanical_editor", "gpt-5.6-luna"),
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
    "sol-advisor-investigator.toml": ("search_scope", "version_date_boundary", "answer", "evidence", "600-1400"),
    "sol-advisor-context-analyst.toml": ("sources", "synthesis_required", "source_locators", "gpt-5.6-luna", "gpt-5.6-terra", "900-2200"),
    "sol-advisor-mechanical-editor.toml": ("owned_files", "edit_point_count", "changed_files", "at least four files", "500-1200"),
    "sol-advisor-local-code-verifier.toml": ("attack_angle", "pass_fail_criteria", "gpt-5.6-luna", "gpt-5.6-sol", "test_gaps", "700-1800"),
    "sol-advisor-final-adjudicator.toml": ("conflicting_claims", "evidence_locators", "ship", "fix_first", "rethink", "700-1600"),
    "sol-advisor-spark-worker.toml": ("mode: scout", "mode: edit", "at most three files", "nineteen", "400-900"),
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
if legacy != set(roles) - {"sol-advisor-spark-worker.toml"}:
    raise SystemExit("legacy upgrade fixture set is incomplete")
for path in legacy_templates.glob("*.toml"):
    tomllib.loads(path.read_text(encoding="utf-8"))
PY
pass "six role configurations, dynamic model profiles, specialized prompts, and 0.7 fixtures"

valid_routes='sol_advisor_spark_worker openai gpt-5.3-codex-spark low
sol_advisor_spark_worker openai gpt-5.3-codex-spark medium
sol_advisor_spark_worker openai gpt-5.3-codex-spark high
sol_advisor_investigator openai gpt-5.6-luna high
sol_advisor_investigator openai gpt-5.6-luna xhigh
sol_advisor_investigator openai gpt-5.6-luna max
sol_advisor_context_analyst openai gpt-5.6-luna high
sol_advisor_context_analyst openai gpt-5.6-terra xhigh
sol_advisor_context_analyst openai gpt-5.6-terra max
sol_advisor_mechanical_editor openai gpt-5.6-luna xhigh
sol_advisor_mechanical_editor openai gpt-5.6-luna max
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
sol_advisor_investigator openai gpt-5.6-luna medium
sol_advisor_context_analyst openai gpt-5.6-luna xhigh
sol_advisor_context_analyst openai gpt-5.6-terra high
sol_advisor_mechanical_editor openai gpt-5.6-terra max
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
pass "quality-preserving six-role route matrix and invalid-route rejection"

clean_target=$tmp_dir/clean-install
sh "$installer" --target-dir "$clean_target" >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$clean_target/$agent_file" || fail "clean install differs: $agent_file"
done
installed_count=$(find "$clean_target" -maxdepth 1 -type f -name 'sol-advisor-*.toml' | awk 'END { print NR + 0 }')
[ "$installed_count" -eq 6 ] || fail "installer did not produce exactly six roles"

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
pass "clean six-role install, exact check, idempotence, and conflict refusal"

upgrade_target=$tmp_dir/managed-upgrade
mkdir "$upgrade_target"
for agent_file in $legacy_agent_files; do cp "$legacy_templates/$agent_file" "$upgrade_target/$agent_file"; done
before_rollback=$(hash_agents "$upgrade_target")
if SOL_ADVISOR_INSTALL_TEST_FAIL_AFTER=2 sh "$installer" --target-dir "$upgrade_target" --upgrade-managed >/dev/null 2>&1; then
  fail "simulated managed-upgrade failure unexpectedly succeeded"
fi
after_rollback=$(hash_agents "$upgrade_target")
[ "$before_rollback" = "$after_rollback" ] || fail "managed-upgrade rollback changed legacy files"
test ! -e "$upgrade_target/sol-advisor-spark-worker.toml" || fail "managed-upgrade rollback left Spark installed"
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
pass "0.7 managed upgrade, exact-hash safety, rollback, and all-or-nothing conflict handling"

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
  for role in sol_advisor_investigator sol_advisor_context_analyst sol_advisor_mechanical_editor sol_advisor_local_code_verifier sol_advisor_final_adjudicator sol_advisor_spark_worker; do
    grep -Fq "$role" "$document" || fail "missing role $role in $document"
  done
  grep -Fq 'AGENTS.md' "$document" || fail "missing project-rule inheritance: $document"
  grep -Fqi 'one corrective' "$document" || grep -Fqi 'one targeted follow-up' "$document" || fail "missing bounded correction rule: $document"
  grep -Fqi 'final response' "$document" || fail "missing native final-response lifecycle: $document"
  grep -Fqi 'parent-interaction' "$document" || fail "missing interaction-message prohibition: $document"
done

grep -Fq 'fork_turns: "none"' "$skill" || fail "missing isolated child spawn rule"
grep -Fq 'Pass both the exact `model`' "$skill" || fail "missing explicit dynamic model and effort rule"
grep -Fq 'weighted quota cost' "$skill" || fail "missing weighted quota objective"
grep -Fq 'accuracy and completion' "$skill" || fail "missing quality-first priority"
grep -Fq 'Keep complex implementation primary' "$skill" || fail "missing complex implementation boundary"
grep -Fq 'Development-time static validation' "$skill" || fail "missing static Python-validation allowance"
grep -Fq 'allow_implicit_invocation: true' "$metadata" || fail "automatic invocation policy missing"
grep -Fq '.agent/authorizations.json' "$skill" || fail "missing implicit authorization file gate"
grep -Fq 'authorizations.solAdvisor.implicitDelegation' "$skill" || fail "missing exact implicit authorization value"
grep -Fq '## Subagent Orchestration' "$skill" || fail "missing managed AGENTS authorization gate"
grep -Fq 'instruction not to' "$skill" || fail "missing explicit no-delegation override"
grep -Fq 'Use zero children' "$skill" || fail "missing zero-child fast path"
grep -Fq 'at most two concurrent children' "$skill" || fail "missing two-child read-only cap"
grep -Fq 'Do not use Final Adjudicator as' "$skill" || fail "missing fixed-chain prevention"
grep -Fq 'Required final fields' "$contracts" || fail "missing role-specific required fields"
grep -Fq 'Optional when nonempty' "$contracts" || fail "missing role-specific optional fields"

for document in "$skill" "$contracts" "$readme"; do
  for retired_field in RETURN_MODE TASK_UNDERSTANDING 'ANSWER/VERDICT' 'DECISION-CHANGING FINDINGS'; do
    if grep -Fq "$retired_field" "$document"; then fail "retired universal field remains in $document: $retired_field"; fi
  done
done
for agent_file in $agent_files; do
  for retired_field in RETURN_MODE TASK_UNDERSTANDING 'ANSWER/VERDICT' 'DECISION-CHANGING FINDINGS'; do
    if grep -Fq "$retired_field" "$templates/$agent_file"; then fail "retired universal field remains in $agent_file: $retired_field"; fi
  done
done
pass "quality gate, specialized contracts, stable spawn configuration, and native lifecycle documentation"

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
pass "static Python checks, shell syntax, LF policy, and Skill size budget"

printf '%s\n' "VERIFY PASSED: Sol Advisor 0.8 no-cost checks completed in $tmp_dir"
