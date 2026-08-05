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
sh "$installer" --check
~~~

Require these native agent types:

- `sol_advisor_repo_scout`
- `sol_advisor_precision_scout`
- `sol_advisor_external_researcher`
- `sol_advisor_mechanical_editor`
- `sol_advisor_context_analyst`
- `sol_advisor_deepseek_adversarial_verifier`
- `sol_advisor_local_code_verifier`
- `sol_advisor_final_adjudicator`

Before the first batch, create one private temporary run directory outside the
repository and retain its state file until the run finishes. Before every spawn batch,
write a dispatch-plan JSON there using the schema in the role contracts and run:

~~~sh
python3 "$dispatch_validator" <temporary-plan.json> \
  --state-file <temporary-run-directory>/state.json
~~~

Spawn only when it returns `"valid":true`. The state file records pending results,
monotonic batch/fix counters, consumed child budget, sticky DeepSeek unavailability,
and completed fallback evidence. Do not delete, replace, or switch state files to reset
a run. Delete the temporary run directory only after completion. Do not manually bypass
a rejected plan.

## Allowed routes

| Task kind | Agent | Model / effort | Access |
|---|---|---|---|
| `repo_search` | `sol_advisor_repo_scout` | Luna / xHigh | read-only |
| `precision_search` | `sol_advisor_precision_scout` | Luna / Max | read-only |
| `external_research` | `sol_advisor_external_researcher` | Luna / xHigh; Max only for high-stakes multi-source reconciliation | read-only |
| `mechanical_edit` | `sol_advisor_mechanical_editor` | Luna / Max | workspace-write |
| `long_context` | `sol_advisor_context_analyst` | Terra / xHigh | read-only |
| `cross_module` | `sol_advisor_context_analyst` | Terra / Max | read-only |
| `adversarial_verification` | `sol_advisor_deepseek_adversarial_verifier` | fixed DeepSeek V4 Flash / Codex xHigh (DeepSeek Max) | read-only |
| `local_verification` | `sol_advisor_local_code_verifier` | Luna / Max | read-only |
| adjudication | `sol_advisor_final_adjudicator` | Sol / Medium, High, xHigh, or Max | read-only |

Luna permits only `xhigh|max`; Terra permits only `xhigh|max`; Sol permits only
`medium|high|xhigh|max`. Ultra is forbidden. Use Sol Medium for bounded low-impact
disputes, High for ordinary semantic conflicts, xHigh for critical code or interface
risk, and Max for architecture rethink, irreversible action, severe verifier conflict,
or DeepSeek-degraded adjudication.

## Probe capabilities and spawn with the exposed interface

Before dispatch validation, inspect the exact spawn schema, exposed custom-agent types,
available providers/models, and the parent turn's effective sandbox and permission
profile. Put those observed capabilities into the plan. Never infer availability from
the repository table and never silently substitute a model.

The supported Codex surfaces currently expose two isolated spawn envelopes:

- Desktop `multi_agent_v1`: send `agent_type`, self-contained `message`, validated
  model/effort overrides, and `fork_context: false`.
- Native CLI: send `agent_type`, unique `task_name`, self-contained `message`, validated
  model/effort overrides, and `fork_turns: "none"`.

Use only the envelope actually exposed by the current tool schema. Reject any other
surface or field combination. For Luna, Terra, and Sol, pass the validated `model` and
`reasoning_effort`. For the fixed DeepSeek role, omit both overrides.

Every message must require one JSON result conforming to the task-adaptive nucleus in
the role contracts and include `RESPONSE TOKEN:` followed by the unique token from the
validated dispatch plan. Save the exact returned text outside the repository and run
`validate-agent-result.py` with the same state file. It validates the actual character
count, exact token, common scope/status fields, and the role-specific evidence nucleus.
Reject a result that fails validation even when routing metadata is correct.

After spawn, inspect public native metadata first. If it omits provider, model, effort,
sandbox, or permission profile and a local rollout is accessible, run the runtime
inspector with the exact child thread id. Public and local values must agree. Run the
route validator against observed values.

Subagents inherit the parent turn's live sandbox and permission overrides. Therefore,
before spawn, require the parent's effective sandbox to be exactly `read-only` for every
investigator, researcher, verifier, analyst, or adjudicator, and exactly
`workspace-write` for the mechanical editor. Never spawn from `danger-full-access` or
with unobservable permission metadata. A post-spawn rejection cannot undo an earlier
side effect. After spawn, pass observed sandbox and permission profile to
`validate-agent-route.sh` and require an exact lane match.

If the required model, agent type, provider, interface, or permission lane is missing,
warn and keep the work in the primary session. For critical verification, report the
lost assurance and do not describe a reduced route as equivalent validation.

## Delegation and budgets

- Use no child when the primary already has sufficient evidence.
- Ordinary: at most one concurrent and one total child.
- Complex: at most two concurrent and three total children.
- Critical: at most three concurrent and five total children.
- Allow at most two fix rounds. When the budget is exhausted, stop delegation and let
  the primary choose `ship`, `fix-first`, or `rethink` from existing evidence.
- Parallel batches must be read-only and have distinct attack angles.
- Spawn every member of a parallel batch before collecting results so validators never
  read each other's conclusions.
- Keep shared files, dependency chains, mechanical writes, and adjudication serial.
- No child may spawn descendants.
- Never reset the run state to regain budget. A dispatched child consumes budget even
  when delivery or validation fails.

The role profiles clear inherited Skill and MCP configuration, but current custom-agent
configuration does not prove a complete denylist for every built-in web, connector,
shell-environment, or plugin capability. Keep a task requiring credentials, specialized
Skills, connectors, or sensitive environment access in the primary session. If the live
surface cannot prove the needed tool boundary, do not spawn and do not call the boundary
"strict".

## Verification and adjudication

After primary implementation and primary verification:

1. Finish low-risk work when no material uncertainty remains.
2. For substantive uncertainty, run one bounded DeepSeek adversarial check.
3. For critical risk, run independent DeepSeek and Luna validators in parallel. Add
   Terra only for a distinct cross-module attack angle.
4. Merge duplicate findings. Reproduce only findings that change implementation,
   block delivery, or require adjudication.
5. Fix clear defects in the primary session and rerun the minimum relevant checks.
6. Send genuine evidence conflicts to the dynamic-strength Sol adjudicator. Its plan
   must name the completed evidence batches in `evidence_batch_ids` and summarize the
   unresolved conflict in `conflict_summary`; never use adjudication as a first batch.

If DeepSeek is unavailable, warn explicitly. For critical verification, run Luna/Max
and Terra/Max in parallel, validate both result nuclei into the same run state, disclose
lost cross-provider independence, and only then permit serial Sol/Max adjudication.
DeepSeek availability is sticky within a run. Never describe the fallback as equivalent
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
