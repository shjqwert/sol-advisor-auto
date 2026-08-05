#!/bin/sh
# Emit only allowlisted routing metadata from one exact native subagent rollout.

set -eu

usage() {
  cat <<'EOF'
Usage: inspect-agent-runtime.sh [--sessions-dir DIR] THREAD_ID

Read the one rollout file whose filename ends with THREAD_ID and emit a compact JSON
object containing only safe routing metadata. Without --sessions-dir, the sessions
root is "$CODEX_HOME/sessions" when CODEX_HOME is already set, otherwise
"$HOME/.codex/sessions".
EOF
}

fail() {
  printf '%s\n' "ERROR: $*" >&2
  exit 1
}

sessions_dir=''
case "$#" in
  1)
    thread_id=$1
    ;;
  3)
    [ "$1" = "--sessions-dir" ] || {
      usage >&2
      exit 2
    }
    [ -n "$2" ] || fail "--sessions-dir requires a non-empty directory."
    sessions_dir=$2
    thread_id=$3
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if ! printf '%s\n' "$thread_id" | LC_ALL=C grep -Eq '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
  fail "THREAD_ID must be a lowercase UUID."
fi

if [ -z "$sessions_dir" ]; then
  if [ -n "${CODEX_HOME-}" ]; then
    sessions_dir=$CODEX_HOME/sessions
  else
    [ -n "${HOME-}" ] || fail "HOME is unset and CODEX_HOME was not supplied; pass --sessions-dir explicitly."
    sessions_dir=$HOME/.codex/sessions
  fi
fi

[ -d "$sessions_dir" ] || fail "sessions directory is unavailable."

tmp_base=${TMPDIR:-/tmp}
case "$tmp_base" in
  /*) ;;
  *) tmp_base=/tmp ;;
esac
matches_file=''

cleanup() {
  if [ -n "$matches_file" ] && [ -f "$matches_file" ]; then
    case "$matches_file" in
      "$tmp_base"/sol-advisor-runtime.*)
        rm -f "$matches_file"
        ;;
      *)
        printf '%s\n' "ERROR: refusing cleanup of unexpected temporary file." >&2
        ;;
    esac
  fi
}

trap cleanup 0 HUP INT TERM

matches_file=$(mktemp "$tmp_base/sol-advisor-runtime.XXXXXX") || fail "could not create a temporary match list."

# Match only the exact rollout filename suffix; do not inspect any rollout contents
# until exactly one filename has been found.
if ! find "$sessions_dir" -type f -name "rollout-*-$thread_id.jsonl" -print > "$matches_file"; then
  fail "could not enumerate rollout filenames under the sessions directory."
fi

match_count=$(awk 'END { print NR + 0 }' "$matches_file")
case "$match_count" in
  0) fail "no rollout filename matched the requested thread id." ;;
  1) ;;
  *) fail "multiple rollout filenames matched the requested thread id." ;;
esac

IFS= read -r rollout_file < "$matches_file" || fail "could not read the matched rollout filename."
[ -f "$rollout_file" ] || fail "matched rollout is unavailable."

# Read only the matched JSONL and construct a new allowlisted object. Reject absent
# or conflicting required routing values instead of inferring them.
if ! python3 - "$rollout_file" "$thread_id" 2>/dev/null <<'PY'
import json
from pathlib import Path
import sys

rollout = Path(sys.argv[1])
expected_thread_id = sys.argv[2]
items = [json.loads(line) for line in rollout.read_text(encoding="utf-8").splitlines() if line.strip()]
sessions = [item.get("payload", {}) for item in items if item.get("type") == "session_meta"]
turns = [item.get("payload", {}) for item in items if item.get("type") == "turn_context"]
if len(sessions) != 1 or not turns:
    raise SystemExit(1)

session = sessions[0]
if session.get("id") != expected_thread_id or not isinstance(session.get("agent_role"), str) or not session["agent_role"]:
    raise SystemExit(1)

def one_required(values):
    if any(not isinstance(value, str) or not value for value in values):
        raise SystemExit(1)
    unique = set(values)
    if len(unique) != 1:
        raise SystemExit(1)
    return values[0]

result = {
    "thread_id": session["id"],
    "parent_thread_id": session.get("parent_thread_id") if isinstance(session.get("parent_thread_id"), str) else None,
    "agent_role": session["agent_role"],
    "agent_path": session.get("agent_path") if isinstance(session.get("agent_path"), str) else None,
    "model_provider": session.get("model_provider") if isinstance(session.get("model_provider"), str) else None,
    "model": one_required([turn.get("model") for turn in turns]),
    "effort": one_required([turn.get("effort") for turn in turns]),
    "sandbox_policy_type": one_required([(turn.get("sandbox_policy") or {}).get("type") for turn in turns]),
    "permission_profile_type": one_required([(turn.get("permission_profile") or {}).get("type") for turn in turns]),
    "cwd": one_required([turn.get("cwd") for turn in turns]),
}
print(json.dumps(result, separators=(",", ":"), ensure_ascii=True))
PY
then
  fail "rollout is missing, ambiguous, invalid, or inconsistent required routing metadata."
fi
