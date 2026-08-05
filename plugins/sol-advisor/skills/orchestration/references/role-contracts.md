# Functional agent contracts

Use the smallest contract that makes one delegated question self-contained. The
contract is adaptive, but every child message must state:

- exact question and bounded scope;
- decision the result can change;
- access and excluded actions;
- expected evidence and output character limit;
- unique response token and stop condition.

Send the complete contract through native `message` with `fork_context: false`.
Reject a result that omits the exact response token.

## Dispatch-plan schema

Before each batch, create a temporary JSON file outside the repository and run
`../../scripts/validate-dispatch-plan.py`. Example:

~~~json
{
  "tier": "complex",
  "phase": "investigation",
  "mode": "parallel",
  "deepseek": "not-required",
  "fix_round": 0,
  "max_fix_rounds": 2,
  "spawned_so_far": 0,
  "max_total_children": 3,
  "routes": [
    {
      "task_kind": "repo_search",
      "role": "sol_advisor_repo_scout",
      "provider": "openai",
      "model": "gpt-5.6-luna",
      "effort": "xhigh",
      "access": "read-only",
      "question": "Locate the routing entry points.",
      "expected_evidence": "Repository paths, symbols, and relevance.",
      "response_token": "SOL_ADVISOR_ROUTE_A1B2C3D4",
      "output_limit_chars": 2000,
      "attack_angle": "repository ownership and entry points"
    },
    {
      "task_kind": "external_research",
      "role": "sol_advisor_external_researcher",
      "provider": "openai",
      "model": "gpt-5.6-luna",
      "effort": "xhigh",
      "access": "read-only",
      "question": "Confirm the current upstream API contract.",
      "expected_evidence": "Primary links, dates, applicability, and fact versus inference.",
      "response_token": "SOL_ADVISOR_ROUTE_E5F6G7H8",
      "output_limit_chars": 2500,
      "attack_angle": "current upstream contract"
    }
  ]
}
~~~

The validator checks the complete route tuple and batch limits. Continue to use
`validate-agent-route.sh` after spawn against observed runtime metadata.

## Evidence nucleus

Do not force one universal report. Require only the nucleus relevant to the claim:

- repository fact: path plus symbol, line, test, or command observation;
- external fact: direct URL, source class (`primary` or `secondary`), publication or
  update date when available, retrieval date, and applicability;
- inference: explicitly label it and name the supporting observations;
- defect: reproducible trigger, impact, and supporting location or test;
- no finding: checked scope and `no blocking issue found`;
- mechanical edit: actual changed paths, verification command, and result;
- unresolved fact: state what remains unknown and why it matters.

The primary verifies only evidence that changes implementation or delivery, but it
must verify at least one concrete locator for every accepted material conclusion.

## Discovery

Use `sol_advisor_repo_scout` with Luna/xHigh for bounded repository discovery, or
`sol_advisor_precision_scout` with Luna/Max for exact call paths and boundaries.

~~~text
QUESTION: <one repository question>
SCOPE: <paths, symbols, and exclusions>
DECISION: <what this can change>
EXPECTED EVIDENCE: <path/symbol/test nucleus>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
STOP: remain read-only; no general review or implementation.
~~~

## External research

Use `sol_advisor_external_researcher` with Luna/xHigh. Escalate to Luna/Max only for
high-stakes reconciliation across multiple primary sources.

~~~text
QUESTION: <one current external fact question>
SCOPE: <domains, versions, date boundary, and exclusions>
DECISION: <what this can change>
SOURCE STANDARD: prefer primary sources; direct URL, source class, date, retrieval
date, applicability, and fact/inference label are required.
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
STOP: read-only search/fetch only; no forms, messages, downloads, or external writes.
~~~

## Context analysis

Use `sol_advisor_context_analyst` with Terra/xHigh for long-context compression or
Terra/Max for independent cross-module constraints.

~~~text
QUESTION: <one long-context or cross-module question>
SOURCES: <bounded files, logs, modules, and exclusions>
DECISION: <what this can change>
EXPECTED EVIDENCE: <source locations and observation/inference labels>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
STOP: remain read-only and omit unrelated summary.
~~~

## Mechanical editing

Use `sol_advisor_mechanical_editor` with Luna/Max only for an exact deterministic
transformation. Never share its batch with another route.

~~~text
CHANGE: <exact transformation>
FILES: <exclusive path list>
PRESERVE: <interfaces and unrelated edits>
VERIFY: <exact command and expected result>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
STOP: if judgment, ambiguity, architecture, dependency expansion, or an out-of-scope
path is required, stop without further changes.
~~~

Capture the complete pre-spawn working-tree status. After return, require the token,
inspect the actual diff, reject any out-of-scope path, and rerun the minimum check.

## Independent verification

Use `sol_advisor_deepseek_adversarial_verifier` for the cross-model angle and
`sol_advisor_local_code_verifier` with Luna/Max for the local code/test angle. Add
Terra/Max only for a distinct cross-module angle. Spawn all members of a parallel
batch before accepting any result so none can see another conclusion.

~~~text
PROPOSED BEHAVIOR: <claim being attacked>
ATTACK ANGLE: <one unique failure class>
SCOPE: <files, interfaces, evidence, and exclusions>
EXPECTED EVIDENCE: <trigger, impact, location/test, or checked no-finding scope>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
STOP: remain read-only; do not implement or inspect another verifier result.
~~~

For DeepSeek, omit model and reasoning overrides because its profile is fixed. Use a
self-contained native message and `fork_context: false` like every other route.

## Sol adjudication

Use `sol_advisor_final_adjudicator` only for a genuine evidence conflict or critical
decision. Choose the task kind matching the validated effort:

- `adjudicate_low` -> Medium
- `adjudicate_standard` -> High
- `adjudicate_critical` -> xHigh
- `adjudicate_max` -> Max

~~~text
DECISION: <ship, fix-first, or rethink question>
EVIDENCE: <compact conflicting claims with locators>
CONSTRAINTS: <safety, compatibility, reversibility, and exclusions>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
RETURN: exact token, one verdict, minimum decisive rationale, and required action.
STOP: remain read-only; do not implement.
~~~

When DeepSeek is unavailable for critical verification, first validate and run a
parallel Luna/Max plus Terra/Max batch with `degraded_independence: true`. Then validate
a separate serial Sol/Max adjudication batch with the same disclosure.
