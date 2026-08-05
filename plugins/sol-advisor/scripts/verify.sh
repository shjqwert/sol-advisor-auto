#!/bin/sh
# No-cost repository-local verification for Sol Advisor.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

agent_files='sol-advisor-repo-scout.toml sol-advisor-precision-scout.toml sol-advisor-external-researcher.toml sol-advisor-mechanical-editor.toml sol-advisor-context-analyst.toml sol-advisor-deepseek-adversarial-verifier.toml sol-advisor-local-code-verifier.toml sol-advisor-final-adjudicator.toml'

hash_agents() {
  for agent_file in $agent_files; do
    sha256sum "$1/$agent_file"
  done | sha256sum | awk '{print $1}'
}

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
plugin_dir=$(CDPATH= cd "$script_dir/.." && pwd) || exit 1
installer=$script_dir/install-agents.sh
route_validator=$script_dir/validate-agent-route.sh
dispatch_validator=$script_dir/validate-dispatch-plan.py
result_validator=$script_dir/validate-agent-result.py
runtime_inspector=$script_dir/inspect-agent-runtime.sh
templates=$plugin_dir/agents
manifest=$plugin_dir/.codex-plugin/plugin.json
skill=$plugin_dir/skills/orchestration/SKILL.md
contracts=$plugin_dir/skills/orchestration/references/role-contracts.md
metadata=$plugin_dir/skills/orchestration/agents/openai.yaml
repo_root=$(CDPATH= cd "$plugin_dir/../.." && pwd) || exit 1
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

for required in "$installer" "$route_validator" "$dispatch_validator" "$result_validator" "$runtime_inspector" "$manifest" "$skill" "$contracts" "$metadata" "$gitattributes"; do
  test -f "$required" || fail "required file missing: $required"
done

python3 - "$manifest" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not manifest.get("version", "").startswith("0.4.1+"):
    raise SystemExit("manifest version was not advanced to 0.4.1")
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
    "sol-advisor-external-researcher.toml": ("sol_advisor_external_researcher", "read-only"),
    "sol-advisor-mechanical-editor.toml": ("sol_advisor_mechanical_editor", "workspace-write"),
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
    if data.get("sandbox_mode") != sandbox:
        raise SystemExit(f"{path}: expected {sandbox} sandbox")
    if data.get("mcp_servers") != {} or data.get("skills", {}).get("config") != []:
        raise SystemExit(f"{path}: inherited MCP or Skill surface was not cleared")
    expected_web = "live" if name == "sol_advisor_external_researcher" else "disabled"
    if data.get("web_search") != expected_web:
        raise SystemExit(f"{path}: unexpected web_search policy")
    shell_policy = data.get("shell_environment_policy", {})
    if shell_policy.get("inherit") != "core" or shell_policy.get("ignore_default_excludes") is not False:
        raise SystemExit(f"{path}: shell environment is not narrowed")
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
    "web_search": "disabled",
}
for field, value in expected.items():
    if deepseek.get(field) != value:
        raise SystemExit(f"{deepseek_path}: {field}={deepseek.get(field)!r}, expected {value!r}")
if deepseek.get("skills", {}).get("config") != []:
    raise SystemExit(f"{deepseek_path}: Skill inheritance was not disabled")
if deepseek.get("features", {}).get("multi_agent") is not False:
    raise SystemExit(f"{deepseek_path}: descendant agents are not disabled")
shell_policy = deepseek.get("shell_environment_policy", {})
if shell_policy.get("inherit") != "core" or shell_policy.get("ignore_default_excludes") is not False:
    raise SystemExit(f"{deepseek_path}: shell environment is not narrowed")
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
pass "dynamic role TOML, narrow tool/access boundaries, fixed DeepSeek route, and no descendants"

valid_routes='sol_advisor_repo_scout openai gpt-5.6-luna xhigh read-only disabled
sol_advisor_precision_scout openai gpt-5.6-luna max read-only disabled
sol_advisor_external_researcher openai gpt-5.6-luna xhigh read-only disabled
sol_advisor_external_researcher openai gpt-5.6-luna max read-only disabled
sol_advisor_mechanical_editor openai gpt-5.6-luna max workspace-write workspace
sol_advisor_context_analyst openai gpt-5.6-terra xhigh read-only disabled
sol_advisor_context_analyst openai gpt-5.6-terra max read-only disabled
sol_advisor_deepseek_adversarial_verifier deepseek deepseek-v4-flash xhigh read-only disabled
sol_advisor_local_code_verifier openai gpt-5.6-luna max read-only disabled
sol_advisor_final_adjudicator openai gpt-5.6-sol medium read-only disabled
sol_advisor_final_adjudicator openai gpt-5.6-sol high read-only disabled
sol_advisor_final_adjudicator openai gpt-5.6-sol xhigh read-only disabled
sol_advisor_final_adjudicator openai gpt-5.6-sol max read-only disabled'
printf '%s\n' "$valid_routes" | while read -r role provider model effort sandbox permission; do
  [ -n "$role" ] || continue
  sh "$route_validator" "$role" "$provider" "$model" "$effort" "$sandbox" "$permission" >/dev/null || fail "valid route rejected: $role $provider $model $effort $sandbox $permission"
done
pass "all allowed dynamic routes"

invalid_routes='sol_advisor_repo_scout openai gpt-5.6-luna high read-only disabled
sol_advisor_precision_scout openai gpt-5.6-luna xhigh read-only disabled
sol_advisor_external_researcher openai gpt-5.6-luna high read-only disabled
sol_advisor_mechanical_editor openai gpt-5.6-luna xhigh workspace-write workspace
sol_advisor_context_analyst openai gpt-5.6-terra ultra read-only disabled
sol_advisor_context_analyst openai gpt-5.6-luna max read-only disabled
sol_advisor_deepseek_adversarial_verifier deepseek deepseek-v4-flash max read-only disabled
sol_advisor_deepseek_adversarial_verifier openai deepseek-v4-flash xhigh read-only disabled
sol_advisor_local_code_verifier openai gpt-5.6-luna xhigh read-only disabled
sol_advisor_final_adjudicator openai gpt-5.6-sol ultra read-only disabled
sol_advisor_repo_scout openai gpt-5.6-luna xhigh workspace-write disabled
sol_advisor_mechanical_editor openai gpt-5.6-luna max danger-full-access disabled
sol_advisor_repo_scout openai gpt-5.6-luna xhigh read-only unobservable'
printf '%s\n' "$invalid_routes" | while read -r role provider model effort sandbox permission; do
  [ -n "$role" ] || continue
  if sh "$route_validator" "$role" "$provider" "$model" "$effort" "$sandbox" "$permission" >/dev/null 2>&1; then
    fail "invalid route accepted: $role $provider $model $effort $sandbox $permission"
  fi
done
pass "illegal Luna, Terra, Sol, and DeepSeek combinations rejected"

python3 - "$dispatch_validator" "$result_validator" <<'PY'
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module

dispatch = load_module("dispatch_validator", Path(sys.argv[1]))
results = load_module("result_validator", Path(sys.argv[2]))
counter = 0

def route(kind, angle=None, native=False):
    global counter
    counter += 1
    role, provider, model, efforts, access = dispatch.ROUTES[kind]
    value = {
        "task_kind": kind,
        "role": role,
        "provider": provider,
        "model": model,
        "effort": sorted(efforts)[-1],
        "access": access,
        "question": f"bounded question {counter}",
        "expected_evidence": "concrete locator and observation",
        "response_token": f"SOL_ADVISOR_TEST_ROUTE_{counter:02d}",
        "output_limit_chars": 2000,
        "attack_angle": angle,
    }
    if native:
        value["task_name"] = f"route-{counter:02d}"
    return value

def plan(run_id, batch_index, tier, phase, mode, routes, deepseek="not-required", native=False, **extra):
    access = {item["access"] for item in routes}
    assert len(access) == 1
    value = {
        "run_id": run_id,
        "batch_id": f"batch-{batch_index:02d}",
        "batch_index": batch_index,
        "task_summary": "bounded repository task",
        "risk_flags": [],
        "tier": tier,
        "phase": phase,
        "mode": mode,
        "deepseek": deepseek,
        "fix_round": 0,
        "spawn_interface": "native_cli" if native else "multi_agent_v1",
        "parent_sandbox": next(iter(access)),
        "parent_permission_profile_type": "disabled",
        "available_agent_types": sorted({value[0] for value in dispatch.ROUTES.values()}),
        "available_models": ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"],
        "available_providers": ["openai", "deepseek"],
        "routes": routes,
    }
    if native:
        value["fork_turns"] = "none"
    else:
        value["fork_context"] = False
    value.update(extra)
    return value

def child_result(item, status="completed"):
    value = {
        "response_token": item["response_token"],
        "status": status,
        "summary": "bounded result",
        "scope": ["plugins/sol-advisor"],
    }
    kind = item["task_kind"]
    if status == "unresolved":
        value["unknowns"] = ["one unresolved fact"]
    elif status == "no_finding":
        pass
    elif kind in {"repo_search", "precision_search", "long_context", "cross_module"}:
        value["locators"] = [{"path": "README.md", "line": 1, "relevance": "evidence"}]
    elif kind == "external_research":
        value["sources"] = [{
            "url": "https://developers.openai.com/codex/",
            "source_class": "primary",
            "retrieved_date": "2026-08-05",
            "applicability": "current Codex",
            "claim": "documented behavior",
            "fact_or_inference": "fact",
        }]
    elif kind in {"adversarial_verification", "local_verification"}:
        value["status"] = "finding"
        value["findings"] = [{"trigger": "condition", "impact": "impact", "locator": "README.md:1"}]
    elif kind == "mechanical_edit":
        value["changed_files"] = ["README.md"]
        value["verification"] = [{"command": "test", "result": "passed"}]
    elif kind.startswith("adjudicate_"):
        value["decision"] = "fix-first"
        value["rationale"] = "material evidence conflict"
    return json.dumps(value, separators=(",", ":"))

ordinary_route = route("repo_search")
ordinary = plan("ordinary-run", 0, "ordinary", "investigation", "serial", [ordinary_route])
ordinary_result, ordinary_state = dispatch.validate(ordinary)
assert ordinary_result["valid"] and ordinary_state["pending_batch"]
try:
    dispatch.validate(deepcopy(ordinary), ordinary_state)
except ValueError:
    pass
else:
    raise SystemExit("pending batch did not block another dispatch")
_, ordinary_done = results.validate_result(child_result(ordinary_route), ordinary_state)
assert ordinary_done["pending_batch"] is None
try:
    second = plan("ordinary-run", 1, "ordinary", "investigation", "serial", [route("repo_search")])
    dispatch.validate(second, ordinary_done)
except ValueError:
    pass
else:
    raise SystemExit("persisted ordinary total budget was reset")

native_route = route("repo_search", native=True)
native = plan("native-run", 0, "ordinary", "investigation", "serial", [native_route], native=True)
assert dispatch.validate(native)[0]["spawn_interface"] == "native_cli"

fallback_routes = [
    route("local_verification", "local code and tests"),
    route("cross_module", "integration boundaries"),
]
fallback = plan(
    "fallback-run", 0, "critical", "verification", "parallel", fallback_routes,
    deepseek="unavailable", degraded_independence=True,
    task_summary="permission boundary verification", risk_flags=["permission_boundary"],
)
_, fallback_state = dispatch.validate(fallback)
for item in fallback_routes:
    status = "no_finding" if item["task_kind"] == "local_verification" else "completed"
    _, fallback_state = results.validate_result(child_result(item, status), fallback_state)
assert fallback_state["fallback_verification_completed"] is True
adjudicator = route("adjudicate_max")
adjudication = plan(
    "fallback-run", 1, "critical", "adjudication", "serial", [adjudicator],
    deepseek="unavailable", degraded_independence=True,
    task_summary="permission boundary adjudication", risk_flags=["permission_boundary"],
    evidence_batch_ids=["batch-00"], conflict_summary="fallback evidence requires final risk disposition",
)
assert dispatch.validate(adjudication, fallback_state)[0]["valid"]

invalid = []
underreported = deepcopy(ordinary)
underreported["task_summary"] = "irreversible production data migration"
invalid.append((underreported, None))
phase_spoof = deepcopy(ordinary)
phase_spoof["phase"] = "adjudication"
invalid.append((phase_spoof, None))
wide_parent = deepcopy(ordinary)
wide_parent["parent_sandbox"] = "danger-full-access"
invalid.append((wide_parent, None))
missing_luna = deepcopy(ordinary)
missing_luna["available_models"] = ["gpt-5.6-sol"]
invalid.append((missing_luna, None))
mixed_interface = deepcopy(ordinary)
mixed_interface["fork_turns"] = "none"
invalid.append((mixed_interface, None))
initial_adjudication = plan(
    "initial-adjudication", 0, "ordinary", "adjudication", "serial", [route("adjudicate_low")],
    evidence_batch_ids=["missing-batch"], conflict_summary="unsupported first-batch dispute",
)
invalid.append((initial_adjudication, None))
duplicate_deepseek = plan(
    "critical-duplicate", 0, "critical", "verification", "parallel",
    [route("adversarial_verification", "angle one"),
     route("adversarial_verification", "angle two"),
     route("local_verification", "angle three")],
    deepseek="available", task_summary="security verification", risk_flags=["security"],
)
invalid.append((duplicate_deepseek, None))
recovered = deepcopy(adjudication)
recovered["deepseek"] = "available"
invalid.append((recovered, fallback_state))
duplicate_batch = plan(
    "ordinary-run", 1, "complex", "investigation", "serial", [route("repo_search")],
    task_summary="multiple modules", risk_flags=["multiple_modules"],
)
duplicate_batch["batch_id"] = "batch-00"
invalid.append((duplicate_batch, ordinary_done))
for rejected, state in invalid:
    try:
        dispatch.validate(rejected, state)
    except ValueError:
        continue
    raise SystemExit(f"invalid dispatch plan accepted: {rejected}")

bad_results = [
    json.dumps({"response_token": "SOL_ADVISOR_WRONG_TOKEN", "status": "no_finding", "summary": "x", "scope": ["x"]}),
    json.dumps({"response_token": ordinary_route["response_token"], "status": "completed", "summary": "x", "scope": ["x"]}),
]
for bad in bad_results:
    try:
        results.validate_result(bad, ordinary_state)
    except ValueError:
        continue
    raise SystemExit("invalid child result was accepted")

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    executable_route = route("repo_search")
    executable_plan = plan("executable-run", 0, "ordinary", "investigation", "serial", [executable_route])
    plan_path = root / "plan.json"
    result_path = root / "result.json"
    state_path = root / "state.json"
    plan_path.write_text(json.dumps(executable_plan), encoding="utf-8")
    first = subprocess.run(
        [sys.executable, sys.argv[1], str(plan_path), "--state-file", str(state_path)],
        capture_output=True, text=True, check=True,
    )
    assert json.loads(first.stdout)["valid"] is True
    result_path.write_text(child_result(executable_route), encoding="utf-8")
    second = subprocess.run(
        [sys.executable, sys.argv[2], str(result_path), "--state-file", str(state_path)],
        capture_output=True, text=True, check=True,
    )
    assert json.loads(second.stdout)["batch_completed"] is True

print("stateful dispatch and adaptive result policy is valid")
PY
pass "risk, phase, interface, permission, availability, stateful budget, fallback, and result policy"

clean_target=$tmp_dir/clean-install
sh "$installer" --target-dir "$clean_target" >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$clean_target/$agent_file" || fail "install differs: $agent_file"
done
installed_count=$(find "$clean_target" -maxdepth 1 -type f -name 'sol-advisor-*.toml' | awk 'END { print NR + 0 }')
[ "$installed_count" -eq 8 ] || fail "installer did not produce exactly eight functional roles"
pass "installer registers exactly eight functional roles"

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

if sh "$installer" --target-dir /tmp/.. --check >/dev/null 2>&1; then fail "installer accepted a path alias resolving to filesystem root"; fi
pass "installer canonical filesystem-root refusal"

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
print(
    data["agent_role"],
    data["model_provider"],
    data["model"],
    data["effort"],
    data["sandbox_policy_type"],
    data["permission_profile_type"],
)
PY
)
set -- $route_fields
sh "$route_validator" "$1" "$2" "$3" "$4" "$5" "$6" >/dev/null
pass "runtime metadata extraction and observed-route validation"

if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" not-a-thread-id >/dev/null 2>&1; then fail "invalid runtime id accepted"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" 22222222-2222-7222-8222-222222222222 >/dev/null 2>&1; then fail "missing rollout accepted"; fi
pass "runtime inspector invalid and missing-id refusal"

for document in "$skill" "$contracts"; do
  for role in sol_advisor_repo_scout sol_advisor_precision_scout sol_advisor_external_researcher sol_advisor_mechanical_editor sol_advisor_context_analyst sol_advisor_deepseek_adversarial_verifier sol_advisor_local_code_verifier sol_advisor_final_adjudicator; do
    grep -Fq "$role" "$document" || fail "missing role $role in $document"
  done
  grep -Fq 'fork_context: false' "$document" || fail "missing Desktop isolated-context spawn rule: $document"
  grep -Fq 'fork_turns: "none"' "$document" || fail "missing native CLI isolated-context spawn rule: $document"
  grep -Fq 'RESPONSE TOKEN' "$document" || fail "missing task-delivery response token: $document"
  grep -Fq 'validate-agent-result.py' "$document" || fail "missing adaptive result validation rule: $document"
done
grep -Fq '../../scripts/validate-dispatch-plan.py' "$skill" || fail "dispatch validator reference missing"
grep -Fq '../../scripts/validate-agent-result.py' "$skill" || fail "result validator reference missing"
grep -Fq -- '--state-file' "$skill" || fail "persistent run-state requirement missing"
grep -Fq "parent turn's effective sandbox and permission" "$skill" || fail "pre-spawn parent permission capability check missing"
grep -Fq 'Ordinary: at most one concurrent and one total child' "$skill" || fail "ordinary concurrency limit missing"
grep -Fq 'Complex: at most two concurrent and three total children' "$skill" || fail "complex concurrency limit missing"
grep -Fq 'Critical: at most three concurrent and five total children' "$skill" || fail "critical concurrency limit missing"
grep -Fq "read each other's conclusions" "$skill" || fail "validator independence missing"
grep -Fq 'serial Sol/Max adjudication' "$skill" || fail "DeepSeek degraded adjudication missing"
grep -Fq 'lost cross-provider independence' "$skill" || fail "DeepSeek degraded disclosure missing"
grep -Fq 'Allow at most two fix rounds' "$skill" || fail "fix-round budget missing"
grep -Fq 'completed evidence batches' "$skill" || fail "adjudication evidence binding missing"
grep -Fq 'allow_implicit_invocation: true' "$metadata" || fail "automatic invocation policy missing"
grep -Fq 'Do not activate for bounded single-module implementation' "$skill" || fail "automatic invocation scope is too broad"
pass "automatic invocation, current spawn interface, budgets, independence, and degradation policies"

python3 - "$dispatch_validator" "$result_validator" <<'PY'
import ast
from pathlib import Path
import sys
for path in sys.argv[1:]:
    ast.parse(Path(path).read_text(encoding="utf-8"))
PY
pass "Python dispatch and result validator syntax"

sh -n "$installer"
sh -n "$route_validator"
sh -n "$runtime_inspector"
sh -n "$script_dir/verify.sh"
for shell_file in "$installer" "$route_validator" "$runtime_inspector" "$script_dir/verify.sh"; do
  if grep -q "$(printf '\r')" "$shell_file"; then fail "CRLF remains in shell script: $shell_file"; fi
done
grep -Fq '*.sh text eol=lf' "$gitattributes" || fail "repository does not enforce LF for shell scripts"
pass "shell syntax and LF policy"

printf '%s\n' "VERIFY PASSED: Sol Advisor no-cost checks completed in $tmp_dir"
