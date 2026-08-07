#!/bin/sh
# Validate the observed role, provider, model, and reasoning effort after spawn.

set -eu

usage() {
  printf '%s\n' 'Usage: validate-agent-route.sh <agent-role> <provider> <model> <effort>'
}

fail() {
  printf '%s\n' "INVALID ROUTE: $*" >&2
  exit 1
}

[ "$#" -eq 4 ] || {
  usage >&2
  exit 2
}

role=$1
provider=$2
model=$3
effort=$4

case "$role:$provider:$model:$effort" in
  sol_advisor_investigator:openai:gpt-5.6-luna:xhigh | \
  sol_advisor_investigator:openai:gpt-5.6-luna:max | \
  sol_advisor_mechanical_editor:openai:gpt-5.6-luna:xhigh | \
  sol_advisor_mechanical_editor:openai:gpt-5.6-luna:max | \
  sol_advisor_mechanical_editor:openai:gpt-5.6-terra:xhigh | \
  sol_advisor_mechanical_editor:openai:gpt-5.6-terra:max | \
  sol_advisor_context_analyst:openai:gpt-5.6-terra:xhigh | \
  sol_advisor_context_analyst:openai:gpt-5.6-terra:max | \
  sol_advisor_local_code_verifier:openai:gpt-5.6-luna:max | \
  sol_advisor_final_adjudicator:openai:gpt-5.6-sol:medium | \
  sol_advisor_final_adjudicator:openai:gpt-5.6-sol:xhigh | \
  sol_advisor_final_adjudicator:openai:gpt-5.6-sol:max)
    printf '%s\n' "VALID ROUTE: $role $provider $model $effort"
    ;;
  *)
    fail "$role $provider $model $effort"
    ;;
esac
