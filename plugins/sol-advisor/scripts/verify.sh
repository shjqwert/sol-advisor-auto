#!/bin/sh
# No-cost repository-local verification for Sol Advisor.

set -eu

pass() { printf '%s\n' "PASS: $*"; }
fail() { printf '%s\n' "FAIL: $*" >&2; exit 1; }

agent_files='sol-advisor-investigator.toml sol-advisor-mechanical-editor.toml sol-advisor-context-analyst.toml sol-advisor-local-code-verifier.toml sol-advisor-final-adjudicator.toml'

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
python_runner=$script_dir/run-python.sh
search_preflight=$script_dir/prepare-repo-search.py
templates=$plugin_dir/agents
manifest=$plugin_dir/.codex-plugin/plugin.json
mcp_config=$plugin_dir/.mcp.json
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

for required in "$installer" "$route_validator" "$dispatch_validator" "$result_validator" "$runtime_inspector" "$python_runner" "$search_preflight" "$manifest" "$mcp_config" "$skill" "$contracts" "$metadata" "$gitattributes"; do
  test -f "$required" || fail "required file missing: $required"
done

sh "$python_runner" - "$manifest" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not manifest.get("version", "").startswith("0.5.0+"):
    raise SystemExit("manifest version was not advanced to 0.5.0")
expected = {
    "author": {"name": "shjqwert", "url": "https://github.com/shjqwert"},
    "homepage": "https://github.com/shjqwert/sol-advisor-auto#readme",
    "repository": "https://github.com/shjqwert/sol-advisor-auto",
}
for field, value in expected.items():
    if manifest.get(field) != value:
        raise SystemExit(f"manifest {field} does not identify the standalone repository")
if manifest.get("mcpServers") != "./.mcp.json":
    raise SystemExit("manifest does not declare the balanced MCP companion")
interface = manifest.get("interface", {})
if interface.get("developerName") != "shjqwert" or interface.get("websiteURL") != expected["repository"]:
    raise SystemExit("manifest interface ownership metadata is stale")
PY
pass "plugin manifest JSON, version, and standalone ownership metadata"

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
    raise SystemExit("unexpected balanced-search MCP set")
PY
pass "balanced Context7, Exa, and MarkItDown MCP configuration"

sh "$python_runner" - "$templates" <<'PY'
from pathlib import Path
import sys
import tomllib

templates = Path(sys.argv[1])
dynamic = {
    "sol-advisor-investigator.toml": ("sol_advisor_investigator", "gpt-5.6-luna"),
    "sol-advisor-mechanical-editor.toml": ("sol_advisor_mechanical_editor", "gpt-5.6-luna"),
    "sol-advisor-context-analyst.toml": ("sol_advisor_context_analyst", "gpt-5.6-terra"),
    "sol-advisor-local-code-verifier.toml": ("sol_advisor_local_code_verifier", "gpt-5.6-luna"),
    "sol-advisor-final-adjudicator.toml": ("sol_advisor_final_adjudicator", "gpt-5.6-sol"),
}
expected_files = set(dynamic)
actual_files = {path.name for path in templates.glob("*.toml")}
if actual_files != expected_files:
    raise SystemExit(f"unexpected custom-agent templates: {sorted(actual_files ^ expected_files)}")
for filename, (name, model) in dynamic.items():
    path = templates / filename
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    for field in ("name", "description", "developer_instructions"):
        if not isinstance(data.get(field), str) or not data[field].strip():
            raise SystemExit(f"{path}: missing {field}")
    if data["name"] != name:
        raise SystemExit(f"{path}: unexpected name {data['name']!r}")
    if data.get("model_provider") != "openai" or data.get("model") != model:
        raise SystemExit(f"{path}: base provider/model pin does not match the role contract")
    if "model_reasoning_effort" in data:
        raise SystemExit(f"{path}: reasoning effort must remain dynamic")
    if "sandbox_mode" in data:
        raise SystemExit(f"{path}: sandbox_mode must be inherited from the parent task")
    if "mcp_servers" in data or "skills" in data:
        raise SystemExit(f"{path}: MCP or Skill inheritance was overridden")
    expected_web = "live" if name == "sol_advisor_investigator" else "disabled"
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
    if "readable markdown first" not in instructions or "sol_advisor_result_json_start" not in instructions:
        raise SystemExit(f"{path}: missing readable result-envelope boundary")
    if "field types exactly" not in instructions:
        raise SystemExit(f"{path}: missing exact machine result-contract boundary")
    if "usage inventories" not in instructions:
        raise SystemExit(f"{path}: missing silent capability-reporting boundary")

print("functional role TOML contracts are valid")
PY
pass "five base-model-pinned role TOML contracts, inherited MCP/Skills and permissions, dynamic effort, and no descendants"

valid_routes='sol_advisor_investigator openai gpt-5.6-luna xhigh
sol_advisor_investigator openai gpt-5.6-luna max
sol_advisor_mechanical_editor openai gpt-5.6-luna xhigh
sol_advisor_mechanical_editor openai gpt-5.6-luna max
sol_advisor_mechanical_editor openai gpt-5.6-terra xhigh
sol_advisor_mechanical_editor openai gpt-5.6-terra max
sol_advisor_context_analyst openai gpt-5.6-terra xhigh
sol_advisor_context_analyst openai gpt-5.6-terra max
sol_advisor_local_code_verifier openai gpt-5.6-luna max
sol_advisor_final_adjudicator openai gpt-5.6-sol medium
sol_advisor_final_adjudicator openai gpt-5.6-sol xhigh
sol_advisor_final_adjudicator openai gpt-5.6-sol max'
printf '%s\n' "$valid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null || fail "valid route rejected: $role $provider $model $effort"
done
pass "all allowed dynamic routes"

invalid_routes='sol_advisor_investigator openai gpt-5.6-luna high
sol_advisor_repo_scout openai gpt-5.6-luna xhigh
sol_advisor_mechanical_editor openai gpt-5.6-terra high
sol_advisor_context_analyst openai gpt-5.6-terra ultra
sol_advisor_context_analyst openai gpt-5.6-luna max
sol_advisor_local_code_verifier openai gpt-5.6-luna xhigh
sol_advisor_final_adjudicator openai gpt-5.6-sol ultra
sol_advisor_final_adjudicator openai gpt-5.6-sol high'
printf '%s\n' "$invalid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  if sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null 2>&1; then
    fail "invalid route accepted: $role $provider $model $effort"
  fi
done
pass "illegal Luna, Terra, and Sol combinations rejected"

sh "$python_runner" - "$dispatch_validator" "$result_validator" <<'PY'
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

def route(kind, angle=None, difficulty=None, model=None, effort=None, selection_reason=None):
    global counter
    counter += 1
    policy = dispatch.ROUTES[kind]
    defaults = {
        "repo_search": ("standard", "gpt-5.6-luna", "xhigh"),
        "precision_search": ("deep", "gpt-5.6-luna", "max"),
        "external_research": ("standard", "gpt-5.6-luna", "xhigh"),
        "mechanical_edit": ("standard", "gpt-5.6-luna", "xhigh"),
        "long_context": (None, "gpt-5.6-terra", "xhigh"),
        "cross_module": (None, "gpt-5.6-terra", "max"),
        "local_verification": (None, "gpt-5.6-luna", "max"),
        "adjudicate_low": (None, "gpt-5.6-sol", "medium"),
        "adjudicate_critical": (None, "gpt-5.6-sol", "xhigh"),
        "adjudicate_max": (None, "gpt-5.6-sol", "max"),
    }
    default_difficulty, default_model, default_effort = defaults[kind]
    difficulty = default_difficulty if difficulty is None else difficulty
    model = default_model if model is None else model
    effort = default_effort if effort is None else effort
    value = {
        "task_kind": kind,
        "role": policy["role"],
        "provider": policy["provider"],
        "model": model,
        "effort": effort,
        "question": f"bounded question {counter}",
        "expected_evidence": "concrete locator and observation",
        "response_token": f"SOL_ADVISOR_TEST_ROUTE_{counter:02d}",
        "output_limit_chars": 2000,
        "attack_angle": angle,
    }
    if kind in dispatch.DIFFICULTY_KINDS:
        value["difficulty"] = difficulty
    if kind in dispatch.INVESTIGATION_KINDS:
        if kind == "external_research":
            value["search"] = {
                "intent": "library_docs",
                "roots": [],
                "include": [],
                "exclude": [],
                "generated_content": "auto",
                "indexing": "never",
                "tool_policy": "auto",
                "fallback_order": ["context7", "web", "exa"],
            }
        else:
            value["search"] = {
                "intent": "call_path",
                "roots": ["/fixture/repository"],
                "include": [],
                "exclude": [],
                "generated_content": "auto",
                "indexing": "create-if-missing",
                "tool_policy": "auto",
                "fallback_order": ["codegraph", "serena", "text"],
            }
    if selection_reason is not None:
        value["selection_reason"] = selection_reason
    value["task_name"] = f"route_{counter:02d}"
    return value

def plan(run_id, batch_index, tier, phase, mode, routes, **extra):
    value = {
        "run_id": run_id,
        "batch_id": f"batch-{batch_index:02d}",
        "batch_index": batch_index,
        "task_summary": "bounded repository task",
        "risk_flags": [],
        "tier": tier,
        "phase": phase,
        "mode": mode,
        "fix_round": 0,
        "spawn_interface": "desktop_collaboration_v2",
        "fork_turns": "none",
        "available_agent_types": sorted({value["role"] for value in dispatch.ROUTES.values()}),
        "available_models": ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"],
        "available_model_overrides": ["gpt-5.6-terra", "gpt-5.6-sol"],
        "available_providers": ["openai"],
        "agent_base_models": {value["role"]: value["base_model"] for value in dispatch.ROUTES.values()},
        "routes": routes,
    }
    value.update(extra)
    return value

def readable_result(value, *, visible_summary=None, visible_status=None, details="Machine evidence is recorded for validation."):
    summary = value["summary"] if visible_summary is None else visible_summary
    status = value["status"] if visible_status is None else visible_status
    scope = ", ".join(value["scope"])
    visible = (
        f"## 结论 / Result\n\n{summary}\n\n"
        f"- 状态 / Status: `{status}`\n"
        f"- 范围 / Scope: {scope}\n"
        f"- 详情 / Details: {details}"
    )
    payload = json.dumps(value, separators=(",", ":"), ensure_ascii=False)
    return f"{visible}\n\n{results.RESULT_JSON_START}{payload}{results.RESULT_JSON_END}"

def child_payload(item, status="completed"):
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
    elif kind == "local_verification":
        value["status"] = "finding"
        value["findings"] = [{"trigger": "condition", "impact": "impact", "locator": "README.md:1"}]
    elif kind == "mechanical_edit":
        value["changed_files"] = ["README.md"]
        value["verification"] = [{"command": "test", "result": "passed"}]
    elif kind.startswith("adjudicate_"):
        value["decision"] = "fix-first"
        value["rationale"] = "material evidence conflict"
    return value

def child_result(item, status="completed"):
    return readable_result(child_payload(item, status))

def runtime_metadata(item, sandbox="danger-full-access", permission="unobservable"):
    return {
        "thread_id": f"runtime-{item['response_token'].lower()}",
        "parent_thread_id": "runtime-parent",
        "agent_role": item["role"],
        "agent_path": f"/root/{item['task_name']}",
        "model_provider": item["provider"],
        "model": item["model"],
        "effort": item["effort"],
        "sandbox_policy_type": sandbox,
        "permission_profile_type": permission,
        "cwd": "/fixture/cwd",
    }

ordinary_route = route("repo_search")
ordinary = plan("ordinary-run", 0, "ordinary", "investigation", "serial", [ordinary_route])
ordinary_result, ordinary_state = dispatch.validate(ordinary)
assert ordinary_result["valid"] and ordinary_state["pending_batch"]
assert ordinary_result["routes"][0]["search"]["intent"] == "call_path"
try:
    dispatch.validate(deepcopy(ordinary), ordinary_state)
except ValueError:
    pass
else:
    raise SystemExit("pending batch did not block another dispatch")
bad_runtime = runtime_metadata(ordinary_route)
bad_runtime["model"] = "gpt-5.6-terra"
try:
    results.validate_result(child_result(ordinary_route), ordinary_state, bad_runtime)
except ValueError:
    pass
else:
    raise SystemExit("mismatched runtime model completed a pending result")
assert ordinary_state["pending_batch"] is not None
malformed_state = deepcopy(ordinary_state)
malformed_state["pending_batch"]["routes"] = [None]
malformed_state = results.with_receipt(malformed_state)
try:
    results.validate_result(child_result(ordinary_route), malformed_state, runtime_metadata(ordinary_route))
except ValueError:
    pass
else:
    raise SystemExit("malformed pending routes did not fail closed")
accepted_runtime = runtime_metadata(ordinary_route)
accepted_runtime.pop("parent_thread_id")
accepted_runtime.pop("agent_path")
_, ordinary_done = results.validate_result(
    child_result(ordinary_route), ordinary_state, accepted_runtime
)
assert ordinary_done["pending_batch"] is None
try:
    second = plan("ordinary-run", 1, "ordinary", "investigation", "serial", [route("repo_search")])
    dispatch.validate(second, ordinary_done)
except ValueError:
    pass
else:
    raise SystemExit("persisted ordinary total budget was reset")

desktop_route = route("repo_search")
desktop = plan("desktop-run", 0, "ordinary", "investigation", "serial", [desktop_route])
desktop_result = dispatch.validate(desktop)[0]
assert desktop_result["spawn_interface"] == "desktop_collaboration_v2"
assert desktop_result["routes"][0]["model_override"] is None

deep_investigation = route("repo_search", difficulty="deep", effort="max")
_, deep_state = dispatch.validate(plan(
    "deep-investigation", 0, "complex", "investigation", "serial", [deep_investigation],
    task_summary="multiple modules", risk_flags=["multiple_modules"],
))
assert deep_state["pending_batch"] is not None
deep_unresolved, _ = results.validate_result(
    child_result(deep_investigation, "unresolved"), deep_state, runtime_metadata(deep_investigation)
)
assert deep_unresolved["status"] == "unresolved"

for run_id, item, risks in [
    ("luna-standard-edit", route("mechanical_edit"), []),
    ("luna-deep-edit", route("mechanical_edit", difficulty="deep", effort="max"), ["multiple_modules"]),
    ("terra-context-edit", route(
        "mechanical_edit", difficulty="deep", model="gpt-5.6-terra", effort="xhigh",
        selection_reason="long_context",
    ), ["long_context"]),
    ("terra-multi-edit", route(
        "mechanical_edit", difficulty="deep", model="gpt-5.6-terra", effort="max",
        selection_reason="long_context",
    ), ["long_context", "multiple_modules"]),
]:
    assert dispatch.validate(plan(
        run_id, 0, "complex" if risks else "ordinary", "editing", "serial", [item],
        task_summary="deterministic mechanical edit", risk_flags=risks,
    ))[0]["valid"]

critical_routes = [
    route("local_verification", "local code and tests"),
    route("cross_module", "integration boundaries"),
]
critical = plan(
    "critical-run", 0, "critical", "verification", "parallel", critical_routes,
    task_summary="permission boundary verification", risk_flags=["permission_boundary"],
)
_, critical_state = dispatch.validate(critical)
for item in critical_routes:
    status = "no_finding" if item["task_kind"] == "local_verification" else "completed"
    _, critical_state = results.validate_result(child_result(item, status), critical_state, runtime_metadata(item))
assert critical_state["pending_batch"] is None
adjudicator = route("adjudicate_critical")
adjudication = plan(
    "critical-run", 1, "critical", "adjudication", "serial", [adjudicator],
    task_summary="permission boundary adjudication", risk_flags=["permission_boundary"],
    evidence_batch_ids=["batch-00"], conflict_summary="independent evidence requires final risk disposition",
)
assert dispatch.validate(adjudication, critical_state)[0]["valid"]

invalid = []
precision_standard = plan(
    "precision-standard", 0, "ordinary", "investigation", "serial",
    [route("precision_search", difficulty="standard", effort="xhigh")],
)
invalid.append((precision_standard, None))
shallow_risky = plan(
    "shallow-risky", 0, "complex", "investigation", "serial", [route("repo_search")],
    task_summary="multiple modules", risk_flags=["multiple_modules"],
)
invalid.append((shallow_risky, None))
terra_without_context = plan(
    "terra-without-context", 0, "complex", "editing", "serial",
    [route(
        "mechanical_edit", difficulty="deep", model="gpt-5.6-terra", effort="xhigh",
        selection_reason="long_context",
    )],
    task_summary="deterministic edit", risk_flags=["behavior_change"],
)
invalid.append((terra_without_context, None))
underreported = deepcopy(ordinary)
underreported["task_summary"] = "irreversible production data migration"
invalid.append((underreported, None))
phase_spoof = deepcopy(ordinary)
phase_spoof["phase"] = "adjudication"
invalid.append((phase_spoof, None))
legacy_permission_plan = deepcopy(ordinary)
legacy_permission_plan["parent_sandbox"] = "danger-full-access"
invalid.append((legacy_permission_plan, None))
legacy_access_route = deepcopy(ordinary)
legacy_access_route["routes"][0]["access"] = "read-only"
invalid.append((legacy_access_route, None))
invalid_task_name = deepcopy(ordinary)
invalid_task_name["routes"][0]["task_name"] = "invalid-task-name"
invalid.append((invalid_task_name, None))
missing_luna = deepcopy(ordinary)
missing_luna["available_models"] = ["gpt-5.6-sol"]
invalid.append((missing_luna, None))
mixed_interface = deepcopy(ordinary)
mixed_interface["spawn_interface"] = "native_cli"
invalid.append((mixed_interface, None))
missing_override = plan(
    "missing-override", 0, "complex", "editing", "serial",
    [route(
        "mechanical_edit", difficulty="deep", model="gpt-5.6-terra", effort="xhigh",
        selection_reason="long_context",
    )],
    task_summary="long context edit", risk_flags=["long_context"],
)
missing_override["available_model_overrides"] = ["gpt-5.6-sol"]
invalid.append((missing_override, None))
bad_base_pin = deepcopy(ordinary)
bad_base_pin["agent_base_models"]["sol_advisor_investigator"] = "gpt-5.6-terra"
invalid.append((bad_base_pin, None))
missing_search = deepcopy(ordinary)
missing_search["routes"][0].pop("search")
invalid.append((missing_search, None))
bad_external_search = plan(
    "bad-external-search", 0, "ordinary", "investigation", "serial", [route("external_research")]
)
bad_external_search["routes"][0]["search"]["indexing"] = "create-if-missing"
invalid.append((bad_external_search, None))
retired_field = deepcopy(ordinary)
retired_field["retired_provider_state"] = "available"
invalid.append((retired_field, None))
initial_adjudication = plan(
    "initial-adjudication", 0, "ordinary", "adjudication", "serial", [route("adjudicate_low")],
    evidence_batch_ids=["missing-batch"], conflict_summary="unsupported first-batch dispute",
)
invalid.append((initial_adjudication, None))
missing_terra = plan(
    "critical-incomplete", 0, "critical", "verification", "serial",
    [route("local_verification", "local-only angle")],
    task_summary="security verification", risk_flags=["security"],
)
invalid.append((missing_terra, None))
duplicate_local = plan(
    "critical-duplicate", 0, "critical", "verification", "parallel",
    [route("local_verification", "angle one"), route("local_verification", "angle two")],
    task_summary="security verification", risk_flags=["security"],
)
invalid.append((duplicate_local, None))
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

old_state = deepcopy(ordinary_done)
old_state["schema_version"] = 7
old_state = dispatch.with_receipt(old_state)
try:
    dispatch.validate(plan("old-state-run", 1, "ordinary", "investigation", "serial", [route("repo_search")]), old_state)
except ValueError:
    pass
else:
    raise SystemExit("retired state schema was accepted")

bad_results = [
    readable_result({"response_token": "SOL_ADVISOR_WRONG_TOKEN", "status": "no_finding", "summary": "x", "scope": ["x"]}),
    readable_result({"response_token": ordinary_route["response_token"], "status": "completed", "summary": "x", "scope": ["x"]}),
    json.dumps(child_payload(ordinary_route), separators=(",", ":")),
    readable_result(child_payload(ordinary_route), visible_summary="different visible summary"),
    readable_result(child_payload(ordinary_route), visible_status="unresolved"),
    readable_result(child_payload(ordinary_route), details="x" * 2100),
    child_result(ordinary_route) + "\n" + results.RESULT_JSON_START + "{}" + results.RESULT_JSON_END,
]
capability_inventory = child_payload(ordinary_route)
capability_inventory["tools_used"] = ["codegraph"]
bad_results.append(readable_result(capability_inventory))
for bad in bad_results:
    try:
        results.validate_result(bad, ordinary_state, runtime_metadata(ordinary_route))
    except ValueError:
        continue
    raise SystemExit("invalid child result was accepted")

wrong_local_evidence = child_payload(ordinary_route)
wrong_local_evidence["sources"] = [{"url": "https://example.com"}]
try:
    results.validate_result(readable_result(wrong_local_evidence), ordinary_state, runtime_metadata(ordinary_route))
except ValueError:
    pass
else:
    raise SystemExit("local investigation accepted external sources")

external_route = route("external_research")
external_plan = plan("external-result", 0, "ordinary", "investigation", "serial", [external_route])
_, external_state = dispatch.validate(external_plan)
wrong_external_evidence = child_payload(external_route)
wrong_external_evidence["locators"] = [{"path": "README.md", "relevance": "wrong nucleus"}]
try:
    results.validate_result(readable_result(wrong_external_evidence), external_state, runtime_metadata(external_route))
except ValueError:
    pass
else:
    raise SystemExit("external research accepted repository locators")

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    executable_route = route("repo_search")
    executable_plan = plan("executable-run", 0, "ordinary", "investigation", "serial", [executable_route])
    plan_path = root / "plan.json"
    result_path = root / "result.json"
    runtime_path = root / "runtime.json"
    state_path = root / "state.json"
    plan_path.write_text(json.dumps(executable_plan), encoding="utf-8")
    first = subprocess.run(
        [sys.executable, sys.argv[1], str(plan_path), "--state-file", str(state_path)],
        capture_output=True, text=True, check=True,
    )
    assert json.loads(first.stdout)["valid"] is True
    result_path.write_text(child_result(executable_route), encoding="utf-8")
    runtime_path.write_text(json.dumps(runtime_metadata(executable_route)), encoding="utf-8")
    second = subprocess.run(
        [
            sys.executable, sys.argv[2], str(result_path), "--state-file", str(state_path),
            "--runtime-metadata", str(runtime_path),
        ],
        capture_output=True, text=True, check=True,
    )
    executable_result = json.loads(second.stdout)
    assert executable_result["batch_completed"] is True
    assert executable_result["visible_chars"] > 0 and executable_result["machine_payload_chars"] > 0

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    real_parent = root / "real"
    real_parent.mkdir()
    linked_parent = root / "linked"
    linked_parent.symlink_to(real_parent, target_is_directory=True)
    for module in (dispatch, results):
        try:
            module.write_state(linked_parent / "state.json", ordinary_done)
        except ValueError:
            continue
        raise SystemExit("state writer accepted a symlinked parent directory")

print("stateful dispatch and adaptive result policy is valid")
PY
pass "risk, phase, interface, inherited permissions, availability, stateful budget, critical verification, and result policy"

clean_target=$tmp_dir/clean-install
sh "$installer" --target-dir "$clean_target" >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$clean_target/$agent_file" || fail "install differs: $agent_file"
done
installed_count=$(find "$clean_target" -maxdepth 1 -type f -name 'sol-advisor-*.toml' | awk 'END { print NR + 0 }')
[ "$installed_count" -eq 5 ] || fail "installer did not produce exactly five functional roles"
pass "installer registers exactly five functional roles"

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
printf '%s\n' conflict > "$conflict_target/sol-advisor-investigator.toml"
if sh "$installer" --target-dir "$conflict_target" >/dev/null 2>&1; then fail "installer overwrote conflict"; fi
test ! -e "$conflict_target/sol-advisor-mechanical-editor.toml" || fail "conflict caused partial install"
pass "installer conflict refusal without partial mutation"

if sh "$installer" --target-dir /tmp/.. --check >/dev/null 2>&1; then fail "installer accepted a path alias resolving to filesystem root"; fi
pass "installer canonical filesystem-root refusal"

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
serena = next(item for item in data["operations"] if item.get("tool") == "serena")
if serena.get("detected_languages") != ["python"]:
    raise SystemExit("index preflight did not infer the fixture language")
if serena.get("command") and serena["command"][-2:] != ["--language", "python"]:
    raise SystemExit("Serena index command did not receive an explicit language")
if (root / ".codegraph").exists() or (root / ".serena").exists():
    raise SystemExit("plan-only index preflight created metadata")
required = {".codegraph/**", ".serena/cache/**", ".serena/indices/**"}
if not required.issubset(set(data.get("raw_search_exclusions", []))):
    raise SystemExit("generic generated-search exclusions are incomplete")
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
pass "portable Python runner and generic CodeGraph/Serena index preflight"

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
sh "$python_runner" - "$runtime_output" <<'PY'
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
route_fields=$(sh "$python_runner" - "$runtime_output" <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
print(
    data["agent_role"],
    data["model_provider"],
    data["model"],
    data["effort"],
)
PY
)
set -- $route_fields
sh "$route_validator" "$1" "$2" "$3" "$4" >/dev/null

inherited_id=33333333-3333-7333-8333-333333333333
inherited_rollout=$runtime_day/rollout-2026-08-05T00-00-01-$inherited_id.jsonl
printf '%s\n' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$inherited_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_investigator\",\"agent_path\":\"/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture/cwd\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"max","cwd":"/fixture/cwd"}}' \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-luna","effort":"max","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture/cwd"}}' \
  > "$inherited_rollout"
inherited_output=$(sh "$runtime_inspector" --sessions-dir "$runtime_sessions" "$inherited_id")
sh "$python_runner" - "$inherited_output" <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
if data.get("sandbox_policy_type") != "mixed-or-partial" or data.get("permission_profile_type") != "mixed-or-partial":
    raise SystemExit("partial inherited permission metadata did not remain diagnostic")
PY
pass "runtime metadata extraction, optional permission diagnostics, and observed-route validation"

if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" not-a-thread-id >/dev/null 2>&1; then fail "invalid runtime id accepted"; fi
if sh "$runtime_inspector" --sessions-dir "$runtime_sessions" 22222222-2222-7222-8222-222222222222 >/dev/null 2>&1; then fail "missing rollout accepted"; fi
pass "runtime inspector invalid and missing-id refusal"

for document in "$skill" "$contracts"; do
  for role in sol_advisor_investigator sol_advisor_mechanical_editor sol_advisor_context_analyst sol_advisor_local_code_verifier sol_advisor_final_adjudicator; do
    grep -Fq "$role" "$document" || fail "missing role $role in $document"
  done
  grep -Fq 'desktop_collaboration_v2' "$document" || fail "missing Desktop collaboration interface: $document"
  grep -Fq 'fork_turns: "none"' "$document" || fail "missing Desktop isolated-context spawn rule: $document"
  grep -Fq 'model_override' "$document" || fail "missing pinned-base-model spawn rule: $document"
  grep -Fq 'RESPONSE TOKEN' "$document" || fail "missing task-delivery response token: $document"
  grep -Fq 'validate-agent-result.py' "$document" || fail "missing adaptive result validation rule: $document"
  grep -Fq 'SOL_ADVISOR_RESULT_JSON_START' "$document" || fail "missing hidden machine-result marker: $document"
done
grep -Fq '../../scripts/validate-dispatch-plan.py' "$skill" || fail "dispatch validator reference missing"
grep -Fq '../../scripts/validate-agent-result.py' "$skill" || fail "result validator reference missing"
grep -Fq -- '--state-file' "$skill" || fail "persistent run-state requirement missing"
grep -Fq 'does not reject or compare inherited' "$skill" || fail "inherited permission policy missing"
grep -Fq -- '--runtime-metadata' "$skill" || fail "runtime-attested result validation missing"
grep -Fq 'Raw JSON-only results are' "$skill" || fail "raw JSON-only result rejection missing"
grep -Fq 'Ordinary: at most one concurrent and one total child' "$skill" || fail "ordinary concurrency limit missing"
grep -Fq 'Complex: at most two concurrent and three total children' "$skill" || fail "complex concurrency limit missing"
grep -Fq 'Critical: at most two concurrent and five total children' "$skill" || fail "critical concurrency limit missing"
grep -Fq "read each other's conclusions" "$skill" || fail "validator independence missing"
grep -Fq 'Luna/Max and Terra/Max validators in parallel' "$skill" || fail "critical independent verification policy missing"
grep -Fq 'Allow at most two fix rounds' "$skill" || fail "fix-round budget missing"
grep -Fq 'completed evidence batches' "$skill" || fail "adjudication evidence binding missing"
grep -Fq 'Role profiles deliberately omit `mcp_servers` and `skills.config`' "$skill" || fail "parent capability inheritance policy missing"
grep -Fq 'Serena, then CodeGraph' "$skill" || fail "symbol search routing policy missing"
grep -Fq 'CodeGraph, then Serena' "$skill" || fail "call-path search routing policy missing"
grep -Fq 'do not add per-child command, elapsed' "$skill" || fail "pilot exploration policy missing"
grep -Fq 'Do not ask a child to enumerate tools' "$skill" || fail "silent capability-probe policy missing"
grep -Fq 'repository or external investigation route includes the generic `search`' "$skill" || fail "generic search dispatch schema missing"
grep -Fq 'allow_implicit_invocation: true' "$metadata" || fail "automatic invocation policy missing"
grep -Fq 'Do not activate for bounded single-module implementation' "$skill" || fail "automatic invocation scope is too broad"
pass "automatic invocation, current spawn interface, budgets, and independent verification policies"

sh "$python_runner" - "$dispatch_validator" "$result_validator" "$search_preflight" <<'PY'
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
sh -n "$python_runner"
sh -n "$script_dir/verify.sh"
for shell_file in "$installer" "$route_validator" "$runtime_inspector" "$python_runner" "$script_dir/verify.sh"; do
  if grep -q "$(printf '\r')" "$shell_file"; then fail "CRLF remains in shell script: $shell_file"; fi
done
grep -Fq '*.sh text eol=lf' "$gitattributes" || fail "repository does not enforce LF for shell scripts"
pass "shell syntax and LF policy"

printf '%s\n' "VERIFY PASSED: Sol Advisor no-cost checks completed in $tmp_dir"
