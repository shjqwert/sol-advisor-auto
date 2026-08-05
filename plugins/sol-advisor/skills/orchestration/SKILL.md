---
name: orchestration
description: "Automatically evaluate non-trivial repository development, debugging, investigation, refactoring, implementation, and code-review tasks for Sol Advisor orchestration. Keep complex implementation in the primary Codex session; delegate only bounded repository search, current external research, long-context analysis, deterministic mechanical edits, or conditional independent verification. Do not activate for trivial one-step questions, simple formatting, casual explanation, or work where delegation cannot reduce context, latency, or verification risk."
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

## Preflight once, validate every batch

Resolve scripts relative to this SKILL.md:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
installer="$skill_dir/../../scripts/install-agents.sh"
route_validator="$skill_dir/../../scripts/validate-agent-route.sh"
dispatch_validator="$skill_dir/../../scripts/validate-dispatch-plan.py"
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

Before every spawn batch, write a temporary dispatch-plan JSON outside the repository
using the schema in the role contracts and run:

~~~sh
python3 "$dispatch_validator" <temporary-plan.json>
~~~

Spawn only when it returns `"valid":true`. Delete the temporary plan after use. The
validator enforces task-role-model-effort mappings, per-tier concurrency, total child
budgets, serial writes, independent attack angles, output limits, fix-round limits,
and the DeepSeek fallback. Do not manually bypass a rejected plan.

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

## Spawn with the current native interface

Send a self-contained task in the native `message` field and set
`fork_context: false`. Do not use a legacy turn-count field; it is not part of the
current native spawn interface. For Luna, Terra, and Sol, pass the validated `model` and
`reasoning_effort`. For the fixed DeepSeek role, omit both overrides.

Every message must include `RESPONSE TOKEN:` followed by the unique token from the
validated dispatch plan.
Reject a result that does not return that exact token, even when routing metadata is
correct. This distinguishes task delivery from role selection.

After spawn, inspect public native metadata first. If it omits provider, model, effort,
sandbox, or permission profile and a local rollout is accessible, run the runtime
inspector with the exact child thread id. Public and local values must agree. Run the
route validator against observed values.

Accept a read-only lane only when its observed sandbox is `read-only`. Accept the
mechanical editor only when its observed sandbox is `workspace-write`; reject
`danger-full-access`, read-only, unobservable, or broadened access. Custom profiles
request narrow access, but live parent overrides can supersede profile defaults.

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

The role profiles clear inherited Skill and MCP configuration. Keep tool use local and
read-only except for the mechanical editor's workspace changes. Use the external
researcher only with side-effect-free search/fetch operations. Keep a task requiring a
specialized Skill or write-capable connector in the primary session unless a separately
reviewed role explicitly provides that narrow tool.

## Verification and adjudication

After primary implementation and primary verification:

1. Finish low-risk work when no material uncertainty remains.
2. For substantive uncertainty, run one bounded DeepSeek adversarial check.
3. For critical risk, run independent DeepSeek and Luna validators in parallel. Add
   Terra only for a distinct cross-module attack angle.
4. Merge duplicate findings. Reproduce only findings that change implementation,
   block delivery, or require adjudication.
5. Fix clear defects in the primary session and rerun the minimum relevant checks.
6. Send genuine evidence conflicts to the dynamic-strength Sol adjudicator.

If DeepSeek is unavailable, warn explicitly. For critical verification, run Luna/Max
and Terra/Max in parallel, disclose lost cross-provider independence, and then require
serial Sol/Max adjudication. Never describe the fallback as equivalent independence.

## Accept child evidence

Child output is a claim, not proof. Require the task-specific evidence nucleus defined
in the role contracts and enforce the validated output character limit. Open only
evidence that can change the plan or delivery decision. Always inspect the actual diff
after a mechanical edit and rerun the minimum relevant checks.

Track main-thread context, total model tokens, elapsed time, child count, rework, and
escaped defects separately. Subagents can reduce main-thread context pollution while
increasing total tokens; never claim total-token savings without a controlled
comparison.
