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

case "$role:$provider:$model" in
  sol_advisor_scout__gpt_5_6_luna:openai:gpt-5.6-luna | \
  sol_advisor_worker__gpt_5_6_sol:openai:gpt-5.6-sol | \
  sol_advisor_reviewer__gpt_5_6_sol:openai:gpt-5.6-sol | \
  sol_advisor_reviewer__gpt_6_astra:openai:gpt-6-astra)
    ;;
  *) fail "$role $provider $model" ;;
esac

# The Skill recommends defaults, not a role-specific effort whitelist.
# Actual host support remains authoritative.
case "$effort" in
  low|medium|high|xhigh|max|ultra) ;;
  *) fail "unknown effort: $effort" ;;
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
