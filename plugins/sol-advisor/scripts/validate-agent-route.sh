#!/bin/sh
# Optional development check for a documented role, model, effort, and task name.

set -eu

usage() {
  printf '%s\n' 'Usage: validate-agent-route.sh <agent-role> <provider> <model> <effort> [task-name]'
}

fail() {
  printf '%s\n' "INVALID ROUTE: $*" >&2
  exit 1
}

case "$#" in
  4|5) ;;
  *) usage >&2; exit 2 ;;
esac

role=$1
provider=$2
model=$3
effort=$4
task_name=${5-}

case "$role:$provider:$model:$effort" in
  sol_advisor_spark_worker:openai:gpt-5.3-codex-spark:low | \
  sol_advisor_spark_worker:openai:gpt-5.3-codex-spark:medium | \
  sol_advisor_spark_worker:openai:gpt-5.3-codex-spark:high | \
  sol_advisor_investigator:openai:gpt-5.6-luna:medium | \
  sol_advisor_investigator:openai:gpt-5.6-luna:high | \
  sol_advisor_investigator:openai:gpt-5.6-luna:xhigh | \
  sol_advisor_investigator:openai:gpt-5.6-luna:max | \
  sol_advisor_mechanical_editor:openai:gpt-5.6-luna:high | \
  sol_advisor_mechanical_editor:openai:gpt-5.6-luna:xhigh | \
  sol_advisor_mechanical_editor:openai:gpt-5.6-luna:max | \
  sol_advisor_test_executor:openai:gpt-5.6-luna:xhigh | \
  sol_advisor_test_executor:openai:gpt-5.6-luna:max | \
  sol_advisor_context_analyst:openai:gpt-5.6-luna:medium | \
  sol_advisor_context_analyst:openai:gpt-5.6-luna:high | \
  sol_advisor_context_analyst:openai:gpt-5.6-terra:high | \
  sol_advisor_context_analyst:openai:gpt-5.6-terra:xhigh | \
  sol_advisor_context_analyst:openai:gpt-5.6-terra:max | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-luna:medium | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-luna:high | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-luna:xhigh | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-luna:max | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-sol:high | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-sol:xhigh | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-sol:max | \
  sol_advisor_local_code_verifier:openai:gpt-6-astra:high | \
  sol_advisor_local_code_verifier:openai:gpt-6-astra:xhigh | \
  sol_advisor_local_code_verifier:openai:gpt-6-astra:max | \
  sol_advisor_final_adjudicator:openai:gpt-5.6-sol:high | \
  sol_advisor_final_adjudicator:openai:gpt-5.6-sol:xhigh | \
  sol_advisor_final_adjudicator:openai:gpt-5.6-sol:max | \
  sol_advisor_final_adjudicator:openai:gpt-6-astra:high | \
  sol_advisor_final_adjudicator:openai:gpt-6-astra:xhigh | \
  sol_advisor_final_adjudicator:openai:gpt-6-astra:max)
    ;;
  *) fail "$role $provider $model $effort" ;;
esac

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
