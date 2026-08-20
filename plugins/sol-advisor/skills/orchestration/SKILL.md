---
name: orchestration
description: "Use for engineering work with long sources, unknown search, focused production, repeated edits, or independent review to decide whether bounded delegation preserves quality and lowers total workflow cost; zero children is valid."
---

# Sol Advisor Orchestration

Treat task accuracy and first-pass completion as hard gates. Among routes that pass
those gates, minimize expected total workflow cost, then reduce primary-context
pollution and latency. Keep requirements, architecture, design-dependent or iterative
implementation, cross-module behavioral changes, final verification, integration,
and release decisions in the primary session. A valid routing decision may use no
child.

Before the first spawn, read the common
[contract index](references/role-contracts.md), then load exactly one selected file
under `references/roles/` as directed by that index.

## Apply the global default and project opt-out

When this plugin is installed and enabled, implicit Sol Advisor route evaluation is
globally allowed in repositories, non-Git directories, empty folders, and from-scratch
workspaces. Do not require a project `.agent` directory, authorization file, managed
`AGENTS.md` section, or version-control root. Global eligibility permits automatic
consideration; it does not require a route-evaluation record, child, or fixed workflow.

Before the first spawn, honor these overrides:

- Codex `agents.enabled = false` disables multi-agent tools and keeps the task primary.
- A schema-v1 `.agent/authorizations.json` at the nearest workspace root with
  `authorizations.solAdvisor.implicitDelegation` exactly `false` disables implicit Sol
  Advisor delegation for that workspace. For a plain non-repository directory, treat
  the current working directory as the workspace root. Exact `true`, a missing file,
  or a missing key leaves the global default enabled.
- An applicable `AGENTS.md` instruction that explicitly disables Sol Advisor or says
  not to delegate disables implicit delegation.
- If an existing project override file is invalid or unreadable, fail safe by keeping
  the task primary until the override is corrected.

Sol Advisor only reads these policy surfaces. Never create, modify, or remove a user-
or project-level `AGENTS.md`, `.agent/context.json`, `.agent/authorizations.json`,
`.agent/planMsg.md`, or `.agent/handoff/` entry. When durable project context is
desired, the separate Project Context plugin owns initialization, synchronization,
policy changes, plans, and handoffs. Sol Advisor remains usable without that plugin;
an absent project override simply inherits the global default.

An explicit current-task user request to use Sol Advisor bypasses a project opt-out.
An explicit current-task instruction not to delegate always wins. Never substitute an
unavailable role, model, or effort.

## Apply the quality and total-cost gates

Delegate only when all quality conditions hold:

- one role owns a bounded question, focused local production goal, repeated exact
  transformation, or frozen ordered test plan;
- the model and effort are adequate for the risk and reasoning difficulty;
- scope, stopping conditions, and completion criteria are explicit;
- the result can be verified without repeating the delegated work; and
- delegation is not expected to reduce first-pass accuracy or completion reliability.

After the quality gate passes, estimate the complete workflow rather than the child
route in isolation. Include:

- primary work avoided and primary work added by dispatch and intake;
- child model, tool, and source-processing work;
- bounded result verification; and
- the probability and cost of a corrective follow-up, escalation, or primary fallback.

Delegate only when expected total workflow cost is lower, when isolating long or noisy
evidence is likely to prevent a quality loss, or when an independent attack angle
materially improves decision quality enough to justify its cost. Context isolation by
itself is not a sufficient benefit.

Use zero children when the primary already has sufficient bounded evidence, when
expected total cost is not lower and there is no material quality benefit, when
dispatch and intake would duplicate the work, or when implementation needs continuing
design judgment. Do not delegate merely because a role exists, because the task has
multiple steps, or because a large context window is available.
Do not require the primary to report or persist a no-delegation decision or
route-evaluation record.

## Consider a cheap prerequisite when useful

When an obvious, cheap, read-only prerequisite could invalidate heavy retrieval or
delegation, consider checking it first. This is optional context hygiene, not a fixed
phase, delegation trigger, or required order. Do not turn it into broad discovery.
When practical, retain complete items from a partial batch and retry only failed,
missing, truncated, or invalidated items.

## Select one route

Treat Spark and GPT-5.6 as separate quota pools. Among routes that pass the quality
gate, start with the lowest adequate model and effort: Spark for eligible light work,
then Luna, Terra for cross-module synthesis, and Sol only for high-risk verification
or genuine adjudication. Escalate only when scope, risk, or evidence requires it.
Higher effort does not compensate for incomplete task facts or an ambiguous packet.

| Scenario | Agent | Allowed route | Responsibility |
|---|---|---|---|
| Exact symbol, relationship, configuration, or log lookup already covered by an available tool | primary session | inherited MCP, index, or exact read | bounded direct lookup |
| Frozen local production goal with compact named inputs and mechanical acceptance | `sol_advisor_spark_worker` | Spark/low, medium, or high; `MODE: PRODUCE` | focused local creation or patch |
| Unknown-location workspace evidence or current official research | `sol_advisor_investigator` | Luna/medium, high, xhigh, or max | read-only investigation |
| Identified long-source extraction or limited summary | `sol_advisor_context_analyst` | Luna/medium or high | read-only extraction |
| Cross-module synthesis or conflicting constraints | `sol_advisor_context_analyst` | Terra/high, xhigh, or max | read-only synthesis |
| Same fully determined transformation repeated across known locations | `sol_advisor_mechanical_editor` | Luna/high, xhigh, or max | repetitive mechanical edit |
| Primary-authored ordered test plan with bounded evidence output | `sol_advisor_test_executor` | Luna/xhigh or max | resumable test execution without fixes |
| Routine through difficult bounded verification | `sol_advisor_local_code_verifier` | Luna/medium, high, xhigh, or max | read-only verification |
| Security, authorization, concurrency, state, data, migration, public-API, or release risk | `sol_advisor_local_code_verifier` | Sol/xhigh; max for irreversible sign-off | read-only high-risk verification |
| Genuine evidence conflict or critical decision | `sol_advisor_final_adjudicator` | Sol/xhigh or max | read-only adjudication |

Reject Spark/xhigh, Context Luna/xhigh or max, Context Terra/medium, Mechanical
Luna/medium, Test Executor Luna/low, medium, or high, Verifier Sol/medium or high, and
Adjudicator Sol/medium or high. If no allowed route fits, keep the work primary.

Do not infer ChatGPT subscription credit multipliers from API pricing thresholds.
Use observed Codex usage when available and otherwise compare relative route cost.
Treat a large context window as available capacity, not a target to fill.

Use an available MCP, index, or exact read in the primary session for bounded symbol,
relationship, configuration, or log lookup. Investigator and Context Analyst are
alternative discovery lanes for the same decision. Spark PRODUCE and Mechanical Editor
are mutually exclusive: use Spark for one local production goal and Mechanical Editor
for one transformation repeated across known locations. Do not add a verifier merely
because another child participated. Do not use Final Adjudicator as a routine closing
step or build a fixed role chain.

Use Test Executor only after the primary freezes an ordered plan with stable test IDs,
dependencies, authorized side effects, pass/fail criteria, evidence output, and stop
conditions. It may record non-blocking findings and continue independent tests, but it
never repairs implementation, changes the plan, or owns final high-risk or release
sign-off.

Test Executor and Local Code Verifier are mutually exclusive for one assignment. Test
Executor owns a frozen primary-authored ordered plan, authorized side effects,
evidence output, and repair-resume state. Local Code Verifier attacks one implementation
or verification claim from one failure class; it must not execute the whole ordered
plan or manage `PLAN_ID` or `RESUME_POINT` state.

## Keep complex implementation primary

Do not delegate implementation that requires design or architecture judgment,
cross-module behavioral changes, public-interface or dependency changes, repeated
debugging, safety-critical implementation, or final integration. Spark and Mechanical
Editor may write only after the primary freezes their respective production goal or
transformation, owned files, preservation rules, completion criteria, and mechanical
check.

## Isolate the primary session

Use one sequence for every child:

`DECIDE -> DISPATCH -> WAIT -> INTAKE -> VERIFY -> ACT`

1. **DECIDE:** name the one decision, exclusive scope, quality gate, and benefit.
2. **DISPATCH:** use the selected contract and send only task-local facts.
3. **WAIT:** do not inspect interim output or independently work the child-owned
   question or source scope. Continue only disjoint work.
4. **INTAKE:** read the ordinary final response once after native completion.
5. **VERIFY:** check zero to two decisive locators without recreating the analysis.
   After any edit, inspect the complete diff and rerun the specified check.
6. **ACT:** integrate, issue one bounded correction, or fall back to the primary.

Two concurrent read-only children require mutually exclusive decisions, source scopes,
and failure classes. Shared files, answer dependencies, edits, follow-ups, and
adjudication remain serial. Children do not communicate directly or form a fixed
pipeline; the primary reviews and transfers any dependent result.

## Spawn with a stable configuration

Use native Desktop collaboration with a unique task name, a minimal self-contained
message, and `fork_turns: "none"`.

- Pinned roles: Investigator/Luna, Mechanical Editor/Luna, Test Executor/Luna, Final
  Adjudicator/Sol, and Spark Worker/Spark. Pass `reasoning_effort`; omit redundant
  model overrides.
- Dynamic roles: Context Analyst and Local Code Verifier. Pass both the exact `model`
  and `reasoning_effort` selected from the route table.
- Spark has no literal automatic effort setting. The primary chooses low, medium, or
  high once before spawn.

At spawn, commit to `role + mode + model + effort + prompt/tool prefix`. Never change
the model or effort inside that child. Keep fixed instructions and tool declarations
before variable task data to avoid configuration-driven prompt-cache misses. This is a
stability rule, not a guarantee of cache hits.

If a useful result misses one bounded requirement, send one targeted follow-up to the
same child with the same configuration. State only the correction, missing evidence,
and prior work to preserve. If stronger capability is required, end the current child
as INCOMPLETE or BLOCKED, then let the primary take over or create at most one new
stronger child and accept the new cold start.

Test Executor has one role-specific lifecycle exception. When it returns `BLOCKED`
with `NEXT_ACTION: REPAIR_RESUME`, the primary may repair the implementation and send
the selected contract's repair-resume packet to the same native child. Keep `PLAN_ID`,
model, effort, and material scope unchanged; rerun the blocking test and invalidated
prerequisites before continuing. Repeat only within that same plan. A new full run,
material plan/scope change, route change, or unusable target state returns
`NEXT_ACTION: NEW_CHILD`.
These repair-resume turns do not consume the one corrective follow-up, and the child
never remains running while the primary repairs.

## Use inherited capabilities safely

Every child follows applicable `AGENTS.md` files and inherited parent instructions,
permissions, sandbox, MCP servers, Skills, web, and shell environment. Role
responsibility constrains side effects; it is not a tool allowlist. Never ask a child
to inventory, install, or reconfigure capabilities.

For workspace relationships prefer Serena or CodeGraph when available; for exact
configuration or logs use exact text search and targeted reads; for versioned APIs use
official documentation or an inherited documentation capability. Missing indexes do
not block bounded exact-text investigation. Do not route such bounded direct lookups
to Spark.

## Handle the native final

Every role returns `STATUS: COMPLETE | INCOMPLETE | BLOCKED` plus only its contract's
required fields and nonempty optional fields. Do not require a universal paragraph
layout. Treat the result as a claim:

- `COMPLETE` and usable: verify decisive evidence and integrate it.
- `INCOMPLETE` and correctable: send one same-child correction without changing model
  or effort.
- Test Executor `BLOCKED` with `NEXT_ACTION: REPAIR_RESUME`: repair in the primary or
  an authorized repair child, then reactivate the same Test Executor with the
  repair-resume packet.
- Test Executor `BLOCKED` with `NEXT_ACTION: NEW_CHILD`: freeze the replacement packet
  and start a new child.
- Test Executor `BLOCKED` with `NEXT_ACTION: PRIMARY_DECISION`, other `BLOCKED`,
  unusable, or still incomplete after correction: take over immediately or report the
  genuine blocker.

Every child activation returns only one ordinary final response and ends immediately.
It must neither send progress, status, or results through parent-interaction messaging
nor remain active. Test Executor may be reactivated after a primary repair but never
waits through that repair. Inspect detailed child history only for a concrete
unusable-final or lifecycle diagnosis.

Do not create a dispatch plan, run directory, `state.json`, pending record, response
token, result path, visible result copy, runtime copy, or machine sidecar. Do not use
Python or another script to accept, reject, or retry a child's natural-language result.
Native child state and its ordinary final are the runtime lifecycle source of truth.
Development-time static validation of TOML, routing, prompts, installers, and fixtures
is allowed and does not participate in dispatch.

## Bound final ownership

- Use zero children unless a quality-preserving benefit is clear; after deciding to
  delegate, use one child by default.
- Use at most two concurrent children, only for independent read-only work.
- Allow at most one corrective follow-up per child. Test Executor repair-resume turns
  are a role-scoped exception for the same frozen plan, not corrective retries.
- Keep all writes serial and inspect their complete diffs.
- Do not let children spawn descendants.
- Keep complex implementation, final verification, integration, and the user response
  in the primary session.
