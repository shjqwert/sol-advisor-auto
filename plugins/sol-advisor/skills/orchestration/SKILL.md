---
name: orchestration
description: "Automatically activate Sol Advisor only when a repository task is likely to benefit from bounded delegation: broad or multi-module search, current external research, long logs or documents, deterministic bulk edits, material implementation uncertainty, critical risk, or independent adversarial verification. Keep complex implementation in the primary Codex session. Do not activate for bounded single-module implementation or debugging the primary can inspect directly, trivial one-step questions, simple formatting, casual explanation, or work where delegation cannot reduce context, latency, or verification risk."
---

# Sol Advisor Orchestration

Keep requirements, architecture, ambiguous reasoning, complex implementation, final
verification, and integration in the primary session. Delegate only bounded work that
can run independently or materially reduces noisy context. A valid decision may use no
child agent.

Before the first spawn, read
[references/role-contracts.md](references/role-contracts.md). Load only the contract
needed for the next batch.

## Classify the task

Choose a tier before selecting a role:

- `ordinary`: local, reversible, bounded, clear acceptance criteria, no material risk
  flags, and no cross-module behavior.
- `complex`: ambiguity, difficult debugging, novel algorithm, long context, multiple
  modules, or a behavior change whose evidence cannot be gathered locally in one step.
- `critical`: security, authentication, concurrency, data loss, migration, production,
  public API, irreversible action, external side effect, or another high-impact flag.

Elevate one tier when evidence is incomplete. Keep an immediate blocking lookup in the
primary session unless it is large enough to cause material context pollution and the
primary can continue independent work while the child runs.

Record explicit `risk_flags` from the dispatch schema. The validator derives a minimum
tier from those flags and conservative critical-risk terms in the task summary; the
declared tier may be higher but never lower. This is a guard against accidental
under-classification, not proof that a model described every semantic risk. When a risk
cannot be classified confidently, do not claim machine-enforced classification.

## Preflight once, validate every batch

Resolve scripts relative to this SKILL.md:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
installer="$skill_dir/../../scripts/install-agents.sh"
route_validator="$skill_dir/../../scripts/validate-agent-route.sh"
dispatch_validator="$skill_dir/../../scripts/validate-dispatch-plan.py"
result_validator="$skill_dir/../../scripts/validate-agent-result.py"
runtime_inspector="$skill_dir/../../scripts/inspect-agent-runtime.sh"
python_runner="$skill_dir/../../scripts/run-python.sh"
search_preflight="$skill_dir/../../scripts/prepare-repo-search.py"
sh "$installer" --check
~~~

Require these native agent types:

- `sol_advisor_investigator`
- `sol_advisor_mechanical_editor`
- `sol_advisor_context_analyst`
- `sol_advisor_local_code_verifier`
- `sol_advisor_final_adjudicator`

Before the first batch, create one private temporary run directory outside the
repository and retain its state file until the run finishes. Before every spawn batch,
write a dispatch-plan JSON there using the schema in the role contracts. Every
repository or external investigation route includes the generic `search` object:
intent, roots, include/exclude, generated-content policy, indexing policy, automatic
tool policy, and fallback order. Then run:

~~~sh
sh "$python_runner" "$dispatch_validator" <temporary-plan.json> \
  --state-file <temporary-run-directory>/state.json
~~~

Spawn only when it returns `"valid":true`. The state file records pending results,
monotonic batch/fix counters, consumed child budget, and completed evidence batches.
Do not delete, replace, or switch state files to reset
a run. Delete the temporary run directory only after completion. Do not manually bypass
a rejected plan.

## Search capabilities and index preparation

Role profiles deliberately omit `mcp_servers` and `skills.config`, so Codex inherits
the parent task's live MCP and Skill configuration. Probe inherited capabilities
silently before assigning a search route. Do not ask a child to enumerate tools and do
not place tool, Skill, MCP, or plugin usage inventories in its visible or machine
result. Runtime diagnostics may retain capability availability, fallback reason, and
elapsed indexing time outside the repository, but these diagnostics are not result
evidence and must not distract the child from its assigned question.

For a local repository route, classify the search intent and use this preference order:

| Intent | Preferred route | Fallback |
|---|---|---|
| symbol, definition, reference | Serena, then CodeGraph | exact text search and targeted reads |
| call path, impact, architecture | CodeGraph, then Serena | exact text search and targeted reads |
| exact text, configuration, logs | exact text search | targeted reads |
| local PDF or Office document | MarkItDown | inherited document/PDF Skill |
| versioned library/API documentation | Context7 | official documentation, then web search |
| current external fact or known page | built-in web, then Exa | primary-source browser retrieval |

Do not deny repository investigation merely because CodeGraph or Serena has no current
index. Before a broad, precision, or cross-module local route, resolve the exact Git
repository root and run the primary-session preflight:

~~~sh
sh "$python_runner" "$search_preflight" <repository-root> \
  --indexing create-if-missing --apply
~~~

Index preparation is a primary-session metadata write. Inspect `git status` before and
after, never stage generated metadata automatically, and stop if the preflight reports
a new tracked-file change. Use `--indexing reuse` when writes are not authorized,
`--indexing refresh` when a stale index is established, and `--indexing never` only
when indexing is explicitly prohibited. If an index tool is unavailable or fails,
continue with exact text search and targeted reads rather than blocking the route.

Raw text search should normally exclude `.codegraph/**`, Serena caches and indices,
`__pycache__`, and common tool caches. Treat generated content as `auto`: do not
globally exclude `.agents`, `.agent`, `.codex`, generated sources, or build output when
the assigned question makes them relevant. Honor task-specific roots, includes, and
excludes over generic defaults. During the pilot, do not add per-child command, elapsed
time, or token ceilings; use bounded questions and explicit stop conditions while
measuring behavior.

## Allowed routes

| Task kind | Agent | Model / effort | Behavioral boundary |
|---|---|---|---|
| `repo_search` | `sol_advisor_investigator` | Luna / xHigh standard; Max deep | no edits |
| `precision_search` | `sol_advisor_investigator` | Luna / Max deep | no edits |
| `external_research` | `sol_advisor_investigator` | Luna / xHigh standard; Max deep | no external writes |
| `mechanical_edit` | `sol_advisor_mechanical_editor` | Luna / xHigh standard; Max deep; Terra only for explicit long context | bounded serial edits |
| `long_context` | `sol_advisor_context_analyst` | Terra / xHigh | no edits |
| `cross_module` | `sol_advisor_context_analyst` | Terra / Max, critical verification only | no edits |
| `local_verification` | `sol_advisor_local_code_verifier` | Luna / Max | no edits |
| adjudication | `sol_advisor_final_adjudicator` | Sol / Medium, xHigh, or Max | no edits |

Luna permits only `xhigh|max`; Terra permits only `xhigh|max`; Sol permits only
`medium|xhigh|max`. Ultra is forbidden. Use Sol Medium for bounded low-impact
disputes, xHigh for critical code or interface risk, and Max for architecture rethink,
irreversible action, severe verifier conflict, or severe evidence conflict.

Every investigation and mechanical-edit route declares `difficulty` as `standard` or
`deep`. Standard Luna routes use xHigh and deep Luna routes use Max. Precision search
is always deep. Multiple modules, difficult debugging, incomplete evidence, or a
critical risk force deep investigation. Terra mechanical editing requires explicit
`long_context` risk and `selection_reason: long_context`; it uses xHigh for one module
and Max when `multiple_modules` is also present. Ordinary cross-module investigation
uses the Luna/Max investigator rather than the context analyst.

## Probe capabilities and spawn in Desktop

Before dispatch validation, inspect the exact spawn schema, exposed custom-agent types,
and available providers/models. Put those observed capabilities into the plan. Never infer availability from
the repository table and never silently substitute a model.

The only supported operational surface is Desktop `desktop_collaboration_v2` so every
child is visible in the sidebar. Send `agent_type`, a unique `task_name`, a self-contained
`message`, `fork_turns: "none"`, and the validated `reasoning_effort`. Do not use
`codex exec` or native CLI spawning for ordinary Sol Advisor execution.

Each role file pins its base model: Luna for investigator, mechanical editor, and
local verifier; Terra for context analyst; Sol for final adjudicator. When the desired
route uses that base model, omit the spawn `model` field (`model_override` is null in
the validated plan). Pass a model override only for an allowed exception, currently
Terra mechanical editing selected by the long-context gate. Treat the catalog model
list, the live schema's model-override list, and the installed role base models as
separate capabilities; reject unavailable combinations without substitution.

Every message must require the readable result envelope in the role contracts and
include `RESPONSE TOKEN:` followed by the unique token from the validated dispatch
plan. The visible section starts with `## 结论 / Result` and shows the exact summary,
status, scope, and concise details. One machine JSON object follows only inside the
`SOL_ADVISOR_RESULT_JSON_START` / `SOL_ADVISOR_RESULT_JSON_END` HTML comment, so the
sidebar renders readable Markdown while validation retains structured evidence. Save
the exact returned text outside the repository, inspect the exact child rollout, and
save the runtime inspector JSON beside it. Run
`validate-agent-result.py` with both the state file and `--runtime-metadata`; it refuses
to mutate state until runtime role, provider, model, and effort match the pending route,
then validates the visible Markdown and hidden JSON contract. Raw JSON-only results are
invalid.

Subagents inherit the parent turn's live sandbox and permission profile. Role files do
not declare a sandbox override, and Sol Advisor does not reject or compare inherited
permissions. Behavioral instructions still prohibit out-of-role actions, and every
mechanical edit remains bounded and serial, but these are not sandbox guarantees.

After spawn, inspect the exact child rollout with the runtime inspector. Pass its JSON
to `validate-agent-result.py --runtime-metadata` and pass role, provider, model, and
effort to `validate-agent-route.sh`. Both must accept before child evidence is used. A
mismatched identity or model route must leave the batch pending. Observed sandbox and
permission fields are diagnostic only.

If the required model, agent type, provider, or interface is missing,
warn and keep the work in the primary session. For critical verification, report the
lost assurance and do not describe a reduced route as equivalent validation.

## Delegation and budgets

- Use no child when the primary already has sufficient evidence.
- Ordinary: at most one concurrent and one total child.
- Complex: at most two concurrent and three total children.
- Critical: at most two concurrent and five total children.
- Allow at most two fix rounds. When the budget is exhausted, stop delegation and let
  the primary choose `ship`, `fix-first`, or `rethink` from existing evidence.
- Parallel batches must contain only non-editing roles and have distinct attack angles.
- Spawn every member of a parallel batch before collecting results so validators never
  read each other's conclusions.
- Keep shared files, dependency chains, mechanical writes, and adjudication serial.
- No child may spawn descendants.
- Never reset the run state to regain budget. A dispatched child consumes budget even
  when delivery or validation fails.

The role profiles inherit the parent task's Skill and MCP configuration. This improves
repository and research capability but is not a strict allowlist. Keep credentialed
writes, sensitive connectors, and external side effects in the primary session; role
instructions permit only the read-only or bounded behavior assigned to that route.

## Verification and adjudication

After primary implementation and primary verification:

1. Finish low-risk work when no material uncertainty remains.
2. For substantive uncertainty, run one bounded Luna/Max local code check.
3. For critical risk, run Luna/Max and Terra/Max validators in parallel with distinct
   local-code and cross-module attack angles.
4. Merge duplicate findings. Reproduce only findings that change implementation,
   block delivery, or require adjudication.
5. Fix clear defects in the primary session and rerun the minimum relevant checks.
6. Send genuine evidence conflicts to the dynamic-strength Sol adjudicator. Its plan
   must name the completed evidence batches in `evidence_batch_ids` and summarize the
   unresolved conflict in `conflict_summary`; never use adjudication as a first batch.

If either critical verifier is unavailable, report the missing assurance and keep the
work in the primary session. Do not substitute another route or claim equivalent
independence.

## Accept child evidence

Child output is a claim, not proof. Require result-validator acceptance first, then open
only evidence that can change the plan or delivery decision. Result validation proves
shape and delivery, not truth. Verify at least one decisive locator for every accepted
material conclusion. Always inspect the actual diff after a mechanical edit and rerun
the minimum relevant checks.

Track main-thread context, total model tokens, elapsed time, child count, rework, and
escaped defects separately. Subagents can reduce main-thread context pollution while
increasing total tokens; never claim total-token savings without a controlled
comparison.
