#!/bin/sh
# Optional development check for a documented role, model, effort, and task name.

set -eu

usage() {
  printf '%s\n' 'Usage: validate-agent-route.sh <agent-role> <provider> <model> <effort> <task-name>'
}

fail() {
  printf '%s\n' "INVALID ROUTE: $*" >&2
  exit 1
}

case "$#" in
  5) ;;
  *) usage >&2; exit 2 ;;
esac

role=$1
provider=$2
model=$3
effort=$4
task_name=$5

case "$role" in
  sol_advisor_scout|sol_advisor_worker|sol_advisor_reviewer) ;;
  *) fail "unknown role: $role" ;;
esac

[ "$provider" = openai ] || fail "unsupported provider: $provider"
# Roles do not restrict models. This is the v3 policy, not proof of host support.
case "$model:$effort" in
  gpt-6-luna:high|gpt-6-luna:xhigh|gpt-6-luna:max | \
  gpt-6-sol:low|gpt-6-sol:medium|gpt-6-sol:high|gpt-6-sol:xhigh|gpt-6-sol:max | \
  gpt-6-astra:low|gpt-6-astra:medium|gpt-6-astra:high|gpt-6-astra:xhigh|gpt-6-astra:max) ;;
  *) fail "unsupported model/effort: $model $effort" ;;
esac

if [ -z "$task_name" ]; then fail "task name is required"; fi
if [ -n "$task_name" ]; then
  case "$task_name" in
    *[!a-z0-9_]*|'') fail "task name must use lowercase letters, digits, and underscores" ;;
  esac
  model_id=$(printf '%s' "$model" | tr '.-' '__')
  case "$task_name" in
    ?*__"$model_id") ;;
    *) fail "task name must end with __$model_id" ;;
  esac
fi

printf '%s\n' "VALID ROUTE: $role $provider $model $effort"
