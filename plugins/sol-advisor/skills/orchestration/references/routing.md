# Routing and coordination

Read this reference only after a bounded role match is identified. Apply policy,
quality, ownership and runtime constraints before spawning. Then read the common
[contract index](role-contracts.md) and exactly one selected role contract.

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

## Apply positive role triggers

Treat task accuracy and first-pass completion as hard gates. A clear role match
permits but never requires delegation. Compare expected benefit with dispatch,
intake and verification overhead. When an upstream Embedded Skill already requires
independent review, select its reviewer without repeating that admission decision.

For every candidate, estimate expected total workflow cost, including dispatch,
child work, intake, decisive checks and likely correction. Quality comes first,
then end-to-end time; quota and context savings must preserve required quality.
Use zero children for a bounded direct lookup, overlapping ownership, unavailable
adequate routes, prohibited delegation or unresolved design decisions. Do not
require a no-delegation report, a routing diagnostic stage or a fixed pipeline.
A RAG result goes directly to the primary unless a separate bounded task needs
independent synthesis or review.

## Consider a cheap prerequisite when useful

When an obvious, cheap, read-only prerequisite could invalidate heavy retrieval or
delegation, consider checking it first. This is optional context hygiene, not a fixed
phase, delegation trigger, or required order. Do not turn it into broad discovery.
When practical, retain complete items from a partial batch and retry only failed,
missing, truncated, or invalidated items.

## Select one route

Treat Spark and the larger review models as separate quota pools. Among routes that
pass the quality gate, select the lowest adequate model and effort: Luna for
bounded work, Terra for cross-module synthesis, Sol for complex or
high-risk verification and routine adjudication, and Astra only for critical review.
Escalate only when scope, risk, or evidence requires it. Higher effort does not
compensate for incomplete task facts or an ambiguous packet.

| Scenario | Agent | Allowed route | Responsibility |
|---|---|---|---|
| Exact symbol, relationship, configuration, or log lookup already covered by an available tool | primary session | inherited MCP, index, or exact read | bounded direct lookup |
| Explicit Spark request or concrete low-latency benefit with compact frozen inputs | `sol_advisor_spark_worker` | Spark/low, medium, or high; `MODE: PRODUCE` | focused local creation or patch |
| Identified long-source extraction or limited summary | `sol_advisor_context_analyst` | Luna/medium or high | read-only extraction |
| Cross-module synthesis or conflicting constraints | `sol_advisor_context_analyst` | Terra/high, xhigh, or max | read-only synthesis |
| Frozen detailed implementation plan with named files, decided behavior, and mechanical checks | `sol_advisor_mechanical_editor` | Luna/high, xhigh, or max | plan-bound implementation |
| Concrete code, test, implementation-correctness, or verification claim | `sol_advisor_local_code_verifier` | Luna/medium, high, xhigh, or max | read-only implementation verification |
| Complex cross-module or high-risk implementation/release claim | `sol_advisor_local_code_verifier` | Sol/high by default; xhigh for difficult cross-module risk; max for rare system sign-off | read-only high-risk verification |
| Critical implementation risk or conflicting implementation evidence within one verification claim | `sol_advisor_local_code_verifier` | Astra/high by default; xhigh across difficult boundaries; max for rare unresolved critical sign-off | read-only critical verification |
| Routine decision-level proposed solution or supplied conflict | `sol_advisor_final_adjudicator` | Sol/high by default; xhigh for complex cross-module decisions; max for rare unresolved high-consequence review | read-only decision review |
| Key architecture, complex long-running task decision, or contested adjudication | `sol_advisor_final_adjudicator` | Astra/high by default; xhigh across difficult boundaries; max only when a rare critical decision cannot converge | read-only critical decision review |

Reject Spark/xhigh, Context Luna/xhigh or max, Context Terra/medium, every Context
Analyst Astra route, Mechanical Luna/medium,
Verifier Sol or Astra below high, and any undocumented Final Adjudicator model or
effort. If no allowed route fits, keep the work primary.

Do not infer ChatGPT subscription credit multipliers from API pricing thresholds.
Use observed Codex usage when available and otherwise compare relative route cost.
Treat a large context window as available capacity, not a target to fill.

Use an available MCP, index, or exact read in the primary session for bounded symbol,
relationship, configuration, or log lookup. Unknown-location discovery stays primary.
Spark PRODUCE and Mechanical Editor are mutually exclusive for one implementation.
Spark requires an explicit request or concrete low-latency benefit; ordinary small
edits do not default to Spark. Mechanical Editor fits frozen batched implementation,
not a default claim of cost savings. Context Analyst fits identified long sources;
the primary prioritizes unresolved items and contradictions over routine spot checks.
If Spark quota is exhausted or unavailable, end its ownership, inspect any existing
diff and continue in the primary without quota waiting or repeated spawn attempts.
A different role requires an explicit new route and actual-model suffix, never impersonation. Do not add a
verifier or Final Adjudicator merely because another child participated. Use Final
Adjudicator only when a proposed solution or supplied conflict has a bounded review
object and an independent adversarial attack can materially improve the decision.

Local Code Verifier and Final Adjudicator are mutually exclusive for one assignment.
Route concrete code, test, implementation-correctness, verification, and release-sign-off
claims to Local Code Verifier, even when the review is adversarial. Route a
decision-level solution whose primary object is goals, constraints, tradeoffs,
assumptions, scope, or accepted risk to Final Adjudicator. Final Adjudicator may inspect
supplied implementation evidence for that decision, or adjudicate supplied conflicting
claims, but it does not perform fresh implementation verification or release sign-off.

## Keep unresolved implementation primary

Do not delegate implementation that still requires product, design, or architecture
judgment, public-interface or dependency decisions, repeated debugging, safety-critical
judgment, or final integration. Spark and Mechanical Editor may write only after the
primary freezes their respective production goal or detailed implementation plan,
owned files, preservation rules, completion criteria, and mechanical checks.

## Isolate the primary session

Use one sequence for every child:

`DECIDE -> DISPATCH -> WAIT -> INTAKE -> VERIFY -> ACT`

1. **DECIDE:** name the one decision, exclusive scope, quality gate, and benefit.
2. **DISPATCH:** use the selected contract and send only task-local facts.
3. **WAIT:** do not inspect interim output or independently work the child-owned
   question or source scope. Continue only disjoint work.
4. **INTAKE:** read the ordinary final response once after native completion.
5. **VERIFY:** inspect decisive evidence without recreating the analysis. For edits,
   inspect the complete diff and the child's reported check evidence. Repeat a check
   only for a concrete gap or invalidated result, within current authorization.
6. **ACT:** integrate, issue one bounded correction, or fall back to the primary.

For findings requiring a change to agreed scope, solution, accepted risk or side
effects, insert `PRESENT -> USER_DECIDE` between VERIFY and ACT. Verified defects
within existing repair authorization may be fixed directly; do not ask again merely
because an independent reviewer found them. Missing authorization remains unknown.

Parallelism follows task dependencies and exclusive ownership, not a fixed count.
Independent read-only work and edits to disjoint files may run concurrently when
they do not share mutable build output, a device, or another exclusive resource.
Dependent tasks and conflicting file/resource owners run serially. Honor native
runtime limits. Each task has one owner; identify the primary's disjoint retained
scope at dispatch. Children do not form a fixed pipeline.

Children do not communicate directly; the primary transfers dependent results.

If a result is incomplete, ask the same child to fill one concrete gap or explicitly
end its ownership before primary takeover. Never let the primary repeat the same
investigation or edits while that child still owns them. Intake integrates the
result; it does not rerun the entire task.

## Spawn with a stable configuration

Use native Desktop collaboration with a unique task name, a minimal self-contained
message, and `fork_turns: "none"`. Name each new child
`<task_summary>__<actual_model_identifier>`; normalize dots and hyphens in the model
to underscores, for example `lock_review__gpt_6_astra`.

- Pinned roles: Mechanical Editor/Luna and
  Spark Worker/Spark. Pass `reasoning_effort`; omit redundant model overrides.
- Dynamic roles: Context Analyst, Local Code Verifier, and Final Adjudicator. Pass both
  the exact `model` and `reasoning_effort` selected from the route table. Context
  Analyst rejects Astra.
- Spark has no literal automatic effort setting. The primary chooses low, medium, or
  high once before spawn.

Changing model requires a new child with a new model suffix. A bounded follow-up on
the same model reuses the existing child and keeps its name and configuration.

At spawn, commit to `role + mode + model + effort + prompt/tool prefix`. Never change
the model or effort inside that child. Keep fixed instructions and tool declarations
before variable task data to avoid configuration-driven prompt-cache misses. This is a
stability rule, not a guarantee of cache hits.

If a useful result misses one bounded requirement, send one targeted follow-up to the
same child with the same configuration. State only the correction, missing evidence,
and prior work to preserve. If stronger capability is required, end the current child
as INCOMPLETE or BLOCKED, then let the primary take over or create at most one new
stronger child and accept the new cold start.

## Use inherited capabilities safely

Every child follows applicable `AGENTS.md` files and inherited parent instructions,
permissions, sandbox, MCP servers, Skills, web, and shell environment. Role
responsibility constrains side effects; it is not a tool allowlist. Applicable
AGENTS.md supplies project rules, Agent TOML supplies role/model boundaries, and
the dispatch prompt supplies task-local facts, scope and completion criteria. Do
not copy the full AGENTS.md into TOML or dispatch; the child observes applicable
nested AGENTS.md when entering its owned paths. Role instructions cannot weaken
project rules. J-Link operations have one named device operator, including reads.
An active capture or unfinished control operation remains with that operator until a
known terminal state or an explicit handoff names the next operator and exact live
state; primary and children make no overlapping device calls. Never ask a child
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
- `BLOCKED`, unusable, or still incomplete after correction: end child ownership and
  take over immediately or report the genuine blocker.

Every child activation returns only one ordinary final response and ends immediately.
It must neither send progress, status, or results through parent-interaction messaging
nor remain active. Inspect detailed child history only for a concrete
unusable-final or lifecycle diagnosis.

Do not create a dispatch plan, run directory, `state.json`, pending record, response
token, result path, visible result copy, runtime copy, or machine sidecar. Do not use
Python or another script to accept, reject, or retry a child's natural-language result.
Native child state and its ordinary final are the runtime lifecycle source of truth.
Development-time static validation of TOML, routing, prompts, installers, and fixtures
is allowed and does not participate in dispatch.

## Bound final ownership

- Do not impose a fixed child-count default or cap. Use the independent task
  decomposition, shared-resource conflicts and native runtime limits.
- Allow at most one corrective follow-up per child.
- Inspect complete edited diffs and honor each file's exclusive owner.
- Do not let children spawn descendants.
- Keep unresolved implementation decisions, final verification, integration and
  the user response in the primary session.
