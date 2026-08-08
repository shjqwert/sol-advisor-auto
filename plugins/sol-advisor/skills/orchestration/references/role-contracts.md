# Functional agent contracts

Use the smallest contract that makes one delegated question self-contained. The
contract is adaptive, but every child message must state:

- exact question and bounded scope;
- decision the result can change;
- behavioral boundaries and excluded actions;
- expected evidence and output character limit;
- unique response token and stop condition;
- one concise Markdown-only final response plus one JSON machine sidecar at the exact
  workspace-local result path using the common envelope and task-specific nucleus below.

Send the complete contract through Desktop `desktop_collaboration_v2` `message`. Every
route uses a unique `task_name` and `fork_turns: "none"` so the child is visible in
the sidebar and receives no inherited conversation. Reject CLI or mixed envelopes.
Reject a result that fails `validate-agent-result.py`.

## Dispatch-plan schema

Resolve the exact workspace first. Git worktrees use
`<git-dir>/sol-advisor/runs/<run-id>/`; SVN and plain directories use
`<workspace-root>/.sol-advisor/runs/<run-id>/` without writing inside `.svn`. For each
batch, write the plan to `plans/<batch-id>.json` below that run directory and use its
`state.json` for the whole run. Do not change ignore files or SVN properties
automatically:

~~~json
{
  "run_id": "sol-run-20260805-a1",
  "batch_id": "discovery-00",
  "batch_index": 0,
  "task_summary": "Investigate multiple modules and the current upstream API.",
  "risk_flags": ["multiple_modules", "evidence_incomplete"],
  "tier": "complex",
  "phase": "investigation",
  "mode": "parallel",
  "fix_round": 0,
  "spawn_interface": "desktop_collaboration_v2",
  "fork_turns": "none",
  "available_agent_types": [
    "sol_advisor_investigator"
  ],
  "available_models": ["gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol"],
  "available_model_overrides": ["gpt-5.6-terra", "gpt-5.6-sol"],
  "available_providers": ["openai"],
  "agent_base_models": {
    "sol_advisor_investigator": "gpt-5.6-luna"
  },
  "routes": [
    {
      "task_kind": "repo_search",
      "role": "sol_advisor_investigator",
      "provider": "openai",
      "model": "gpt-5.6-luna",
      "effort": "xhigh",
      "difficulty": "standard",
      "question": "Locate the routing entry points.",
      "expected_evidence": "Repository paths, symbols, and relevance.",
      "search": {
        "intent": "call_path",
        "roots": ["/exact/repository/root"],
        "include": [],
        "exclude": [],
        "generated_content": "auto",
        "indexing": "create-if-missing",
        "tool_policy": "auto",
        "fallback_order": ["codegraph", "serena", "text"]
      },
      "response_token": "SOL_ADVISOR_ROUTE_A1B2C3D4",
      "output_limit_chars": 2000,
      "attack_angle": "repository ownership and entry points"
      ,"task_name": "investigate_routing_a1"
    },
    {
      "task_kind": "external_research",
      "role": "sol_advisor_investigator",
      "provider": "openai",
      "model": "gpt-5.6-luna",
      "effort": "xhigh",
      "difficulty": "standard",
      "question": "Confirm the current upstream API contract.",
      "expected_evidence": "Primary links, dates, applicability, and fact versus inference.",
      "search": {
        "intent": "library_docs",
        "roots": [],
        "include": [],
        "exclude": [],
        "generated_content": "auto",
        "indexing": "never",
        "tool_policy": "auto",
        "fallback_order": ["context7", "web", "exa"]
      },
      "response_token": "SOL_ADVISOR_ROUTE_E5F6G7H8",
      "output_limit_chars": 2500,
      "attack_angle": "current upstream contract"
      ,"task_name": "research_upstream_e5"
    }
  ]
}
~~~

~~~sh
sh ../../scripts/run-python.sh ../../scripts/validate-dispatch-plan.py \
  <run-directory>/plans/<batch-id>.json --repository <repository-root> \
  --state-file <run-directory>/state.json
~~~

The normalized route includes `model_override`, `result_path`, `visible_path`, and
`runtime_path`. Omit the spawn `model` field when `model_override` is null, because the
role's TOML base-model pin is authoritative. Supply the override only when it is
non-null and exposed by the live Desktop schema. Send the exact `result_path` to the
child; the primary owns `visible_path` and `runtime_path`.

An adjudication batch additionally requires unique `evidence_batch_ids` naming prior
completed batches in the same state file and a concise `conflict_summary`. Adjudication
cannot be the first batch and a `batch_id` cannot be reused within a run.

The validator derives a minimum tier from `risk_flags` and conservative critical terms,
binds route kinds to phases, and verifies current model/agent/provider availability. It
persists budget state but does not restrict inherited child permissions. It cannot prove
that a model identified every semantic risk. Continue to use
`validate-agent-route.sh` after spawn against observed role, provider, model, and effort.

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

Every child writes the machine object to its assigned `RESULT PATH`, then returns this
exact Markdown-only structure in the sidebar:

~~~text
## 结论 / Result

<exactly the same text as the JSON summary>

- 状态 / Status: `<exact JSON status>`
- 范围 / Scope: <compact human-readable scope>
- 详情 / Details: <concise evidence, changed files, unknowns, or decision>
~~~

Do not expose or append the JSON anywhere in the final response. The visible Markdown
is capped at 2000 characters; the validated `output_limit_chars` applies to the JSON
sidecar. The visible section must use the exact machine summary and status. Machine
JSON in the final response and raw JSON-only final output are invalid.

The machine sidecar common envelope is intentionally small:

~~~json
{
  "response_token": "SOL_ADVISOR_ROUTE_A1B2C3D4",
  "status": "completed",
  "summary": "One concise task-specific conclusion.",
  "scope": ["exact files, symbols, sources, or checks examined"]
}
~~~

Then add only the task-specific nucleus:

- repository/context result: `locators` objects with `path`, `relevance`, and optional
  `symbol`/positive `line`;
- external result: `sources` objects with `url`, `source_class`, `retrieved_date`,
  `applicability`, `claim`, and `fact_or_inference`;
- verification finding: `findings` objects with `trigger`, `impact`, and `locator`;
- mechanical completion: `changed_files` and `verification` command/result objects;
- adjudication: `decision` (`ship|fix-first|rethink`) and `rationale`;
- unresolved result: `unknowns`; no-finding result relies on the checked `scope`.

Repository and precision results must not include `sources`; external-research results
must not include repository `locators`. If assigned investigation difficulty is too
low, return `unresolved` and name the required upgrade in `unknowns`.

The child must finish writing the sidecar before it returns. The primary saves the
exact returned Markdown to `visible_path`, saves runtime inspection JSON to
`runtime_path`, then runs:

~~~sh
sh ../../scripts/run-python.sh ../../scripts/validate-agent-result.py <visible-path> \
  --machine-result <result-path> --repository <repository-root> --run-id <run-id> \
  --state-file <run-directory>/state.json --runtime-metadata <runtime-path>
~~~

Result validation checks that every artifact uses the exact pending-route path, checks
the visible heading plus exact machine summary/status and bounded size, then binds the
child runtime role, provider, model, and effort to the pending route. Sandbox and
permission metadata are diagnostic only and do not gate acceptance. Validation proves
delivery and evidence shape, not truth; the primary confirms or rejects decisive
evidence before use.

The primary verifies only evidence that changes implementation or delivery, but it
must verify at least one concrete locator for every accepted material conclusion.

## Discovery

Use `sol_advisor_investigator` with Luna/xHigh for standard bounded repository
discovery and Luna/Max for deep discovery. Precision search is always deep. Multiple
modules, difficult debugging, incomplete evidence, or critical risk also require deep.
For local task kinds, explicitly forbid web use even though the unified role keeps
live read-only search available for external research.

~~~text
QUESTION: <one repository question>
SCOPE: <paths, symbols, and exclusions>
SEARCH INTENT: <symbol|call_path|architecture|text|document>
INDEX POLICY: <reuse|create-if-missing|refresh|never; prepared by the primary>
GENERATED CONTENT: <auto|include|exclude, with task-specific exceptions>
DECISION: <what this can change>
EXPECTED EVIDENCE: <path/symbol/test nucleus>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
RESULT PATH: <validated absolute machine-sidecar path>
FINAL OUTPUT: Markdown only; write JSON to RESULT PATH before returning.
STOP: remain read-only; no general review or implementation.
~~~

## External research

Use `sol_advisor_investigator` with Luna/xHigh for standard external research. Use
Luna/Max deep for high-stakes reconciliation, incomplete evidence, or conflicting
primary sources.

~~~text
QUESTION: <one current external fact question>
SCOPE: <domains, versions, date boundary, and exclusions>
DECISION: <what this can change>
SOURCE STANDARD: prefer primary sources; direct URL, source class, date, retrieval
date, applicability, and fact/inference label are required.
SEARCH ROUTE: Context7 for versioned library docs; built-in web then Exa for current
facts; use only the narrow capability that matches the question.
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
RESULT PATH: <validated absolute machine-sidecar path>
FINAL OUTPUT: Markdown only; write JSON to RESULT PATH before returning.
STOP: read-only search/fetch only; no forms, messages, downloads, or external writes.
~~~

## Context analysis

Use `sol_advisor_context_analyst` with Terra/xHigh for long-context compression or
Terra/Max for critical independent cross-module verification. Use the Luna/Max
investigator for ordinary cross-module investigation.

~~~text
QUESTION: <one long-context or cross-module question>
SOURCES: <bounded files, logs, modules, and exclusions>
DECISION: <what this can change>
EXPECTED EVIDENCE: <source locations and observation/inference labels>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
RESULT PATH: <validated absolute machine-sidecar path>
FINAL OUTPUT: Markdown only; write JSON to RESULT PATH before returning.
STOP: remain read-only and omit unrelated summary.
~~~

## Mechanical editing

Use `sol_advisor_mechanical_editor` with Luna/xHigh for a standard deterministic edit
or Luna/Max for a deep deterministic edit. Terra requires `difficulty: deep`, a
`long_context` risk, and `selection_reason: long_context`; use Terra/xHigh for one
module and Terra/Max when `multiple_modules` is also present. Never share its batch
with another route.

~~~text
CHANGE: <exact transformation>
FILES: <exclusive path list>
PRESERVE: <interfaces and unrelated edits>
VERIFY: <exact command and expected result>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
RESULT PATH: <validated absolute machine-sidecar path>
FINAL OUTPUT: Markdown only; write JSON to RESULT PATH before returning.
STOP: if judgment, ambiguity, architecture, dependency expansion, or an out-of-scope
path is required, stop without further changes.
~~~

Capture the complete pre-spawn working-tree status. After return, require the token,
inspect the actual diff, reject any out-of-scope path, and rerun the minimum check.

## Independent verification

Use `sol_advisor_local_code_verifier` with Luna/Max for substantive implementation
uncertainty. For critical risk, pair it with `sol_advisor_context_analyst` at Terra/Max
for a distinct cross-module angle. Spawn both members of the parallel batch before
accepting either result so neither can see the other's conclusion.

~~~text
PROPOSED BEHAVIOR: <claim being attacked>
ATTACK ANGLE: <one unique failure class>
SCOPE: <files, interfaces, evidence, and exclusions>
EXPECTED EVIDENCE: <trigger, impact, location/test, or checked no-finding scope>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
RESULT PATH: <validated absolute machine-sidecar path>
FINAL OUTPUT: Markdown only; write JSON to RESULT PATH before returning.
STOP: remain read-only; do not implement or inspect another verifier result.
~~~

Use a self-contained native message. Omit the model field for the role's validated base
model; pass a model override only for an explicitly allowed exception, and always pass
the validated reasoning effort.

## Sol adjudication

Use `sol_advisor_final_adjudicator` only for a genuine evidence conflict or critical
decision. Choose the task kind matching the validated effort:

- `adjudicate_low` -> Medium
- `adjudicate_critical` -> xHigh
- `adjudicate_max` -> Max

~~~text
DECISION: <ship, fix-first, or rethink question>
EVIDENCE: <compact conflicting claims with locators>
CONSTRAINTS: <safety, compatibility, reversibility, and exclusions>
OUTPUT LIMIT: <validated characters>
RESPONSE TOKEN: <validated unique token>
RESULT PATH: <validated absolute machine-sidecar path>
FINAL OUTPUT: Markdown only; write JSON to RESULT PATH before returning.
RETURN: exact token, one verdict, minimum decisive rationale, and required action.
STOP: remain read-only; do not implement.
~~~

Critical verification requires one Luna/Max local-code route and one Terra/Max
cross-module route with distinct attack angles. If either route is unavailable, keep
the verification in the primary session and report the missing assurance. Sol effort
remains dynamic and adjudication is permitted only for a genuine conflict backed by
completed evidence batches.
