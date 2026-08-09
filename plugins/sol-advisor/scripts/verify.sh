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

for retired in "$script_dir/validate-dispatch-plan.py" "$script_dir/validate-agent-result.py" "$script_dir/sol_advisor_paths.py"; do
  test ! -e "$retired" || fail "retired runtime protocol file remains: $retired"
done
pass "retired dispatch, result, and run-state scripts are absent"

sh "$python_runner" - "$manifest" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not manifest.get("version", "").startswith("0.6.0+"):
    raise SystemExit("manifest version was not advanced to 0.6.0")
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
prompts = " ".join(manifest.get("interface", {}).get("defaultPrompt", []))
if "native child status and results" not in prompts or "targeted corrective follow-up" not in prompts:
    raise SystemExit("manifest prompts do not describe the native fallback flow")
PY
pass "plugin manifest JSON, version, ownership, and native workflow metadata"

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
pass "Context7, Exa, and MarkItDown MCP configuration"

sh "$python_runner" - "$templates" <<'PY'
from pathlib import Path
import sys
import tomllib

templates = Path(sys.argv[1])
roles = {
    "sol-advisor-investigator.toml": ("sol_advisor_investigator", "gpt-5.6-luna"),
    "sol-advisor-mechanical-editor.toml": ("sol_advisor_mechanical_editor", "gpt-5.6-luna"),
    "sol-advisor-context-analyst.toml": ("sol_advisor_context_analyst", "gpt-5.6-terra"),
    "sol-advisor-local-code-verifier.toml": ("sol_advisor_local_code_verifier", "gpt-5.6-luna"),
    "sol-advisor-final-adjudicator.toml": ("sol_advisor_final_adjudicator", "gpt-5.6-sol"),
}
actual = {path.name for path in templates.glob("*.toml")}
if actual != set(roles):
    raise SystemExit(f"unexpected custom-agent templates: {sorted(actual ^ set(roles))}")
for filename, (name, model) in roles.items():
    path = templates / filename
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    if data.get("name") != name or data.get("model_provider") != "openai" or data.get("model") != model:
        raise SystemExit(f"{path}: unexpected role or base model")
    for forbidden in ("model_reasoning_effort", "sandbox_mode", "mcp_servers", "skills", "web_search", "shell_environment_policy"):
        if forbidden in data:
            raise SystemExit(f"{path}: inherited capability was overridden by {forbidden}")
    if data.get("features", {}).get("multi_agent") is not False:
        raise SystemExit(f"{path}: descendant agents are not disabled")
    instructions = " ".join(data.get("developer_instructions", "").split()).lower()
    for required in ("applicable agents.md", "inherited mcp and skill", "no tool allowlist or denylist", "ordinary result"):
        if required not in instructions:
            raise SystemExit(f"{path}: missing inherited-capability rule: {required}")
    for forbidden in ("result path", "sidecar", "machine-result", "state.json", "pending"):
        if forbidden in instructions:
            raise SystemExit(f"{path}: retired result protocol remains: {forbidden}")
context = tomllib.loads((templates / "sol-advisor-context-analyst.toml").read_text(encoding="utf-8"))
context_instructions = context["developer_instructions"].lower()
if not all(f"at {effort}" in context_instructions for effort in ("high", "xhigh", "max")):
    raise SystemExit("Context Analyst does not describe high, xhigh, and max effort")
PY
pass "five roles inherit AGENTS.md, MCP, Skills, permissions, web, and shell capabilities"

valid_routes='sol_advisor_investigator openai gpt-5.6-luna xhigh
sol_advisor_investigator openai gpt-5.6-luna max
sol_advisor_mechanical_editor openai gpt-5.6-luna xhigh
sol_advisor_mechanical_editor openai gpt-5.6-luna max
sol_advisor_context_analyst openai gpt-5.6-terra high
sol_advisor_context_analyst openai gpt-5.6-terra xhigh
sol_advisor_context_analyst openai gpt-5.6-terra max
sol_advisor_local_code_verifier openai gpt-5.6-luna max
sol_advisor_final_adjudicator openai gpt-5.6-sol medium
sol_advisor_final_adjudicator openai gpt-5.6-sol xhigh
sol_advisor_final_adjudicator openai gpt-5.6-sol max'
printf '%s\n' "$valid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null || fail "documented route rejected: $role $provider $model $effort"
done

invalid_routes='sol_advisor_investigator openai gpt-5.6-luna high
sol_advisor_context_analyst openai gpt-5.6-terra medium
sol_advisor_mechanical_editor openai gpt-5.6-terra max
sol_advisor_final_adjudicator openai gpt-5.6-sol ultra'
printf '%s\n' "$invalid_routes" | while read -r role provider model effort; do
  [ -n "$role" ] || continue
  if sh "$route_validator" "$role" "$provider" "$model" "$effort" >/dev/null 2>&1; then
    fail "undocumented diagnostic route accepted: $role $provider $model $effort"
  fi
done
pass "optional route diagnostic includes Terra high and rejects undocumented combinations"

clean_target=$tmp_dir/clean-install
sh "$installer" --target-dir "$clean_target" >/dev/null
for agent_file in $agent_files; do
  cmp -s "$templates/$agent_file" "$clean_target/$agent_file" || fail "install differs: $agent_file"
done
installed_count=$(find "$clean_target" -maxdepth 1 -type f -name 'sol-advisor-*.toml' | awk 'END { print NR + 0 }')
[ "$installed_count" -eq 5 ] || fail "installer did not produce exactly five functional roles"

missing_check_target=$tmp_dir/missing-check
if sh "$installer" --target-dir "$missing_check_target" --check >/dev/null 2>&1; then fail "--check accepted missing target"; fi
test ! -e "$missing_check_target" || fail "--check mutated missing target"

before_repeat=$(hash_agents "$clean_target")
sh "$installer" --target-dir "$clean_target" >/dev/null
sh "$installer" --target-dir "$clean_target" --check >/dev/null
after_repeat=$(hash_agents "$clean_target")
[ "$before_repeat" = "$after_repeat" ] || fail "repeat install/check changed files"

conflict_target=$tmp_dir/conflict
mkdir "$conflict_target"
printf '%s\n' conflict > "$conflict_target/sol-advisor-investigator.toml"
if sh "$installer" --target-dir "$conflict_target" >/dev/null 2>&1; then fail "installer overwrote conflict"; fi
test ! -e "$conflict_target/sol-advisor-mechanical-editor.toml" || fail "conflict caused partial install"
pass "installer exactness, idempotence, non-mutating check, and conflict refusal"

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
if (root / ".codegraph").exists() or (root / ".serena").exists():
    raise SystemExit("plan-only index preflight created metadata")
if ".sol-advisor/**" in data.get("raw_search_exclusions", []):
    raise SystemExit("retired runtime directory remains in search exclusions")
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
runtime_day=$runtime_sessions/2026/08/09
mkdir -p "$runtime_day"
runtime_id=11111111-1111-7111-8111-111111111111
runtime_rollout=$runtime_day/rollout-2026-08-09T00-00-00-$runtime_id.jsonl
printf '%s\n' \
  '{"type":"response_item","payload":{"prompt":"DO_NOT_LEAK"}}' \
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"$runtime_id\",\"parent_thread_id\":\"00000000-0000-7000-8000-000000000000\",\"agent_role\":\"sol_advisor_context_analyst\",\"agent_path\":\"/fixture\",\"model_provider\":\"openai\",\"cwd\":\"/fixture/cwd\"}}" \
  '{"type":"turn_context","payload":{"model":"gpt-5.6-terra","effort":"high","sandbox_policy":{"type":"danger-full-access"},"permission_profile":{"type":"disabled"},"cwd":"/fixture/cwd"}}' \
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
    "effort": "high",
}
if any(data.get(key) != value for key, value in expected.items()):
    raise SystemExit("runtime inspector returned unexpected route")
PY
printf '%s\n' "$runtime_output" | grep -Fq DO_NOT_LEAK && fail "runtime inspector leaked prompt"
pass "optional runtime inspector supports the Terra high route without leaking content"

for document in "$skill" "$contracts" "$readme"; do
  for role in sol_advisor_investigator sol_advisor_mechanical_editor sol_advisor_context_analyst sol_advisor_local_code_verifier sol_advisor_final_adjudicator; do
    grep -Fq "$role" "$document" || fail "missing role $role in $document"
  done
  grep -Fq 'AGENTS.md' "$document" || fail "missing project-rule inheritance: $document"
  grep -Fqi 'MCP' "$document" || fail "missing MCP capability rule: $document"
  grep -Fqi 'inherit' "$document" || fail "missing capability inheritance: $document"
  grep -Fqi 'one targeted' "$document" || grep -Fqi 'one corrective' "$document" || fail "missing bounded follow-up: $document"
done
grep -Fq 'fork_turns: "none"' "$skill" || fail "missing native isolated child spawn rule"
grep -Fq 'the primary takes over immediately' "$skill" || fail "missing primary fallback"
grep -Fq 'Terra / High, xHigh, or Max' "$skill" || fail "missing Context Analyst high route"
grep -Fq 'allow_implicit_invocation: true' "$metadata" || fail "automatic invocation policy missing"

for retired_text in 'validate-dispatch-plan.py' 'validate-agent-result.py' 'sol_advisor_paths.py' 'RESULT PATH' 'RESPONSE TOKEN' 'pending_batch' '.sol-advisor/runs' '<git-dir>/sol-advisor/runs'; do
  if grep -R -Fq --exclude='verify.sh' --exclude-dir='__pycache__' "$retired_text" "$plugin_dir" "$readme"; then
    fail "retired protocol reference remains: $retired_text"
  fi
done
pass "native workflow, capability inheritance, one follow-up, primary fallback, and retired-protocol removal"

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
pass "Python syntax, shell syntax, and LF policy"

printf '%s\n' "VERIFY PASSED: Sol Advisor no-cost checks completed in $tmp_dir"
