#!/bin/sh
# No-cost repository-local verification for Sol Advisor.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

agent_files='sol-advisor-repo-scout.toml sol-advisor-precision-scout.toml sol-advisor-mechanical-editor.toml sol-advisor-context-analyst.toml sol-advisor-deepseek-adversarial-verifier.toml sol-advisor-local-code-verifier.toml sol-advisor-final-adjudicator.toml'

hash_agents() {
  for agent_file in $agent_files; do
    sha256sum "$1/$agent_file"
  done | sha256sum | awk '{print $1}'
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
route_validator=$script_dir/validate-agent-route.sh
runtime_inspector=$script_dir/inspect-agent-runtime.sh
templates=$plugin_dir/agents
manifest=$plugin_dir/.codex-plugin/plugin.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
metadata=$plugin_dir/skills/orchestration/agents/openai.yaml

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

for required in "$installer" "$route_validator" "$runtime_inspector" "$manifest" "$skill" "$contracts" "$metadata"; do
  test -f "$required" || fail "required file missing: $required"
done

python3 - "$manifest" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not manifest.get("version", "").startswith("0.3."):
    raise SystemExit("manifest version was not advanced to 0.3")
PY
pass "plugin manifest JSON and version"

python3 - "$templates" <<'PY'
from pathlib import Path
import sys
import tomllib

templates = Path(sys.argv[1])
dynamic = {
    "sol-advisor-repo-scout.toml": ("sol_advisor_repo_scout", "read-only"),
    "sol-advisor-precision-scout.toml": ("sol_advisor_precision_scout", "read-only"),
    "sol-advisor-mechanical-editor.toml": ("sol_advisor_mechanical_editor", None),
    "sol-advisor-context-analyst.toml": ("sol_advisor_context_analyst", "read-only"),
    "sol-advisor-local-code-verifier.toml": ("sol_advisor_local_code_verifier", "read-only"),
    "sol-advisor-final-adjudicator.toml": ("sol_advisor_final_adjudicator", "read-only"),
}
expected_files = set(dynamic) | {"sol-advisor-deepseek-adversarial-verifier.toml"}
actual_files = {path.name for path in templates.glob("*.toml")}
if actual_files != expected_files:
    raise SystemExit(f"unexpected custom-agent templates: {sorted(actual_files ^ expected_files)}")
for filename, (name, sandbox) in dynamic.items():
    path = templates / filename
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise SystemExit(f"{path}: missing {field}")
    if data["name"] != name:
        raise SystemExit(f"{path}: unexpected name {data['name']!r}")
    if "model" in data or "model_reasoning_effort" in data or "model_provider" in data:
        raise SystemExit(f"{path}: dynamic role unexpectedly pins provider/model/effort")
    if sandbox is None:
        if "sandbox_mode" in data:
            raise SystemExit(f"{path}: mechanical editor must inherit writable parent access")
    elif data.get("sandbox_mode") != sandbox:
        raise SystemExit(f"{path}: expected {sandbox} sandbox")
    if data.get("features", {}).get("multi_agent") is not False:
        raise SystemExit(f"{path}: descendant agents are not disabled")
    instructions = " ".join(data["developer_instructions"].lower().split())
    if "do not spawn" not in instructions or "plugin" not in instructions or "mcp" not in instructions:
        raise SystemExit(f"{path}: missing child/plugin/MCP boundary")

deepseek_path = templates / "sol-advisor-deepseek-adversarial-verifier.toml"
deepseek = tomllib.loads(deepseek_path.read_text(encoding="utf-8"))
expected = {
    "name": "sol_advisor_deepseek_adversarial_verifier",
    "model_provider": "deepseek",
    "model": "deepseek-v4-flash",
    "model_reasoning_effort": "xhigh",
    "sandbox_mode": "read-only",
    "mcp_servers": {},
}
for field, value in expected.items():
    if deepseek.get(field) != value:
        raise SystemExit(f"{deepseek_path}: {field}={deepseek.get(field)!r}, expected {value!r}")
if deepseek.get("skills", {}).get("config") != []:
    raise SystemExit(f"{deepseek_path}: Skill inheritance was not disabled")
if deepseek.get("features", {}).get("multi_agent") is not False:
    raise SystemExit(f"{deepseek_path}: descendant agents are not disabled")
provider = deepseek.get("model_providers", {}).get("deepseek", {})
for field, value in {
    "base_url": "https://api.deepseek.com",
    "wire_api": "responses",
    "env_key": "DEEPSEEK_API_KEY",
}.items():
    if provider.get(field) != value:
        raise SystemExit(f"{deepseek_path}: invalid provider {field}")

print("functional role TOML contracts are valid")
PY
pass "dynamic role TOML, access boundaries, fixed DeepSeek route, and no descendants"

valid_routes='sol_advisor_repo_scout openai gpt-5.6-luna xhigh
sol_advisor_precision_scout openai gpt-5.6-luna max
sol_advisor_mechanical_editor openai gpt-5.6-luna max
sol_advisor_context_analyst openai gpt-5.6-terra xhigh
sol_advisor_context_analyst openai gpt-5.6-terra max
sol_advisor_deepseek_adversarial_verifier deepseek deepseek-v4-flash xhigh
sol_advisor_local_code_verifier openai gpt-5.6-luna max
sol_advisor_final_adjudicator openai gpt-5.6-sol medium
sol_advisor_final_adjudicator openai gpt-5.6-sol high
sol_advisor_final_adjudicator openai gpt-5.6-sol xhigh
sol_advisor_final_adjudicator openai gpt-5.6-sol max'
printf '%s\n' "$valid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null || fail "valid route rejected: $role $provider $model $effort"
done
pass "all allowed dynamic routes"

invalid_routes='sol_advisor_repo_scout openai gpt-5.6-luna high
sol_advisor_precision_scout openai gpt-5.6-luna xhigh
sol_advisor_mechanical_editor openai gpt-5.6-luna xhigh
sol_advisor_context_analyst openai gpt-5.6-terra ultra
sol_advisor_context_analyst openai gpt-5.6-luna max
sol_advisor_deepseek_adversarial_verifier deepseek deepseek-v4-flash max
sol_advisor_deepseek_adversarial_verifier openai deepseek-v4-flash xhigh
sol_advisor_local_code_verifier openai gpt-5.6-luna xhigh
sol_advisor_final_adjudicator openai gpt-5.6-sol ultra'
printf '%s\n' "$invalid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  if sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null 2>&1; then
    fail "invalid route accepted: $role $provider $model $effort"
  fi
done
pass "illegal Luna, Terra, Sol, and DeepSeek combinations rejected"

clean_target=$tmp_dir/clean-install
sh "$installer" --target-dir "$clean_target" >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$clean_target/$agent_file" || fail "install differs: $agent_file"
done
installed_count=$(find "$clean_target" -maxdepth 1 -type f -name 'sol-advisor-*.toml' | awk 'END { print NR + 0 }')
[ "$installed_count" -eq 7 ] || fail "installer did not produce exactly seven functional roles"
pass "installer registers exactly seven functional roles"

missing_check_target=$tmp_dir/missing-check
if sh "$installer" --target-dir "$missing_check_target" --check >/dev/null 2>&1; then fail "--check accepted missing target"; fi
test ! -e "$missing_check_target" || fail "--check mutated missing target"
pass "installer check is non-mutating"

before_repeat=$(hash_agents "$clean_target")
sh "$installer" --target-dir "$clean_target" >/dev/null
sh "$installer" --target-dir "$clean_target" --check >/dev/null
after_repeat=$(hash_agents "$clean_target")
[ "$before_repeat" = "$after_repeat" ] || fail "repeat install/check changed files"
pass "installer repeat and check are idempotent"

conflict_target=$tmp_dir/conflict
mkdir "$conflict_target"
printf '%s\n' conflict > "$conflict_target/sol-advisor-repo-scout.toml"
if sh "$installer" --target-dir "$conflict_target" >/dev/null 2>&1; then fail "installer overwrote conflict"; fi
test ! -e "$conflict_target/sol-advisor-precision-scout.toml" || fail "conflict caused partial install"
pass "installer conflict refusal without partial mutation"

runtime_sessions=$tmp_dir/runtime-sessions
runtime_day=$runtime_sessions/2026/08/05
mkdir -p "$runtime_day"
runtime_id=11111111-1111-7111-8111-111111111111
runtime_rollout=$runtime_day/rollout-2026-08-05T00-00-00-$runtime_id.jsonl
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_context_analyst\",\"agent_path\":\"/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture/cwd\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"max","sandbox_policy":{"type":"read-only"},"permission_profile":{"type":"disabled"},"cwd":"/fixture/cwd"}}' \
  > "$runtime_rollout"
runtime_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$runtime_id")
python3 - "$runtime_output" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
expected = {
    "agent_role": "sol_advisor_context_analyst",
    "model_provider": "openai",
    "model": "gpt-5.6-terra",
    "effort": "max",
    "sandbox_policy_type": "read-only",
    "permission_profile_type": "disabled",
}
if any(data.get(key) != value for key, value in expected.items()):
    raise SystemExit("runtime inspector returned unexpected route")
PY
printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK && fail "runtime inspector leaked prompt"
route_fields=$(python3 - "$runtime_output" <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
print(data["agent_role"], data["model_provider"], data["model"], data["effort"])
PY
)
set -- $route_fields
sh "$route_validator" "$1" "$2" "$3" "$4" >/dev/null
pass "runtime metadata extraction and observed-route validation"

if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" not-a-thread-id >/dev/null 2>&1; then fail "invalid runtime id accepted"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" 22222222-2222-7222-8222-222222222222 >/dev/null 2>&1; then fail "missing rollout accepted"; fi
pass "runtime inspector invalid and missing-id refusal"

for document in "$skill" "$contracts"; do
  for role in sol_advisor_repo_scout sol_advisor_precision_scout sol_advisor_mechanical_editor sol_advisor_context_analyst sol_advisor_deepseek_adversarial_verifier sol_advisor_local_code_verifier sol_advisor_final_adjudicator; do
    grep -Fq "$role" "$document" || fail "missing role $role in $document"
  done
  grep -Fq 'fork_turns: 1' "$document" || fail "missing positive inherited-context rule: $document"
done
grep -Fq 'Ordinary task: at most one child agent' "$skill" || fail "ordinary concurrency limit missing"
grep -Fq 'Complex task: at most two' "$skill" || fail "complex concurrency limit missing"
grep -Fq 'third validator' "$skill" || fail "critical concurrency limit missing"
grep -Fq "read each other's conclusions" "$skill" || fail "validator independence missing"
grep -Fq 'force Sol/Max adjudication' "$skill" || fail "DeepSeek degraded adjudication missing"
grep -Fq 'cross-provider independence' "$skill" || fail "DeepSeek degraded disclosure missing"
grep -Fq 'ordinary completion does not require' "$skill" || fail "conditional Sol adjudication missing"
grep -Fq 'does not automatically execute a Skill' "$skill" || fail "explicit child Skill rule missing"
grep -Fq 'allow_implicit_invocation: false' "$metadata" || fail "explicit invocation policy missing"
pass "concurrency, independence, conditional validation, degradation, and Skill policies"

sh -n "$installer"
sh -n "$route_validator"
sh -n "$runtime_inspector"
sh -n "$script_dir/verify.sh"
pass "shell syntax"

printf '%s\n' "VERIFY PASSED: Sol Advisor no-cost checks completed in $tmp_dir"
