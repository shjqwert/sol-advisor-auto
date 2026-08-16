---
name: orchestration
description: "Automatically activate Sol Advisor for authorized-project repository work when quality-preserving bounded delegation is likely to reduce primary-context load or weighted quota cost, or materially improve independent verification: exact Spark scouting or small edits, unknown-location investigation, identified long-source synthesis, large deterministic edits, risk-based local verification, or genuine evidence adjudication. Keep design-dependent or iterative implementation and final integration in the primary Codex session. Do not activate for trivial work, already-bounded primary work, or any route that can reduce accuracy or completion reliability."
---

# Sol Advisor Orchestration

Prioritize, in order: task accuracy and completion, primary-context isolation, weighted
quota cost, then latency. Keep requirements, architecture, design-dependent or iterative
implementation, cross-module behavioral changes, final verification, integration, and
release decisions in the primary session. A valid routing decision may use no child.

Before the first spawn, read
[references/role-contracts.md](references/role-contracts.md). Load only the selected
role or Spark mode contract.

## Authorize implicit delegation

For implicit use, spawn no child unless both signals are present:

- the nearest project root contains schema-v1 `.agent/authorizations.json` with
  `authorizations.solAdvisor.implicitDelegation` exactly `true`; and
- the applicable managed `AGENTS.md` section contains the corresponding
  `## Subagent Orchestration` authorization instruction.

Treat any missing, invalid, false, unreadable, or one-sided signal as no implicit
authorization and continue in the primary session. Explicit user invocation of Sol
Advisor bypasses this project gate for that task. An explicit instruction not to
delegate always wins. Never substitute an unavailable role, model, or effort.

## Apply the quality and benefit gates

Delegate only when all quality conditions hold:

- one role owns a bounded question or exact deterministic edit;
- the model and effort are adequate for the risk and reasoning difficulty;
- scope, stopping conditions, and completion criteria are explicit;
- the result can be verified without repeating the delegated work; and
- delegation is not expected to reduce first-pass accuracy or completion reliability.

After the quality gate passes, require at least one material benefit:

- the child keeps broad search, long sources, or noisy evidence out of primary context;
- the child uses a lower weighted quota route without reducing quality; or
- an independent attack angle materially improves confidence.

Use zero children when the primary already has sufficient bounded evidence, when
dispatch and intake would duplicate the work, or when implementation needs continuing
design judgment. Do not delegate merely because a role exists or because the task has
multiple steps.

## Select one route

Treat Spark and GPT-5.6 as separate quota pools. Among routes that pass the quality
gate, prefer the lowest effective quota cost: Spark for eligible light work, then Luna,
Terra for cross-module synthesis, and Sol only for high-risk verification or genuine
adjudication. Do not hard-code benchmark scores, prices, or latency as routing gates.

| Scenario | Agent | Allowed route | Responsibility |
|---|---|---|---|
| Exact lookup, inventory, or narrow path mapping | `sol_advisor_spark_worker` | Spark/low, medium, or high; `MODE: SCOUT` | read-only light scouting |
| At most 3 files and 19 low-risk deterministic edit points | `sol_advisor_spark_worker` | Spark/medium or high; `MODE: EDIT` | small serial edit |
| Unknown-location repository evidence or current official research | `sol_advisor_investigator` | Luna/high, xhigh, or max | read-only investigation |
| Identified long-source extraction or limited summary | `sol_advisor_context_analyst` | Luna/high | read-only extraction |
| Cross-module synthesis or conflicting constraints | `sol_advisor_context_analyst` | Terra/xhigh; max for critical constraints | read-only synthesis |
| At least 4 files, or 20 same-type points across at least 2 files | `sol_advisor_mechanical_editor` | Luna/xhigh or max | large deterministic edit |
| Routine through difficult bounded verification | `sol_advisor_local_code_verifier` | Luna/high, xhigh, or max | read-only verification |
| Security, authorization, concurrency, state, data, migration, public-API, or release risk | `sol_advisor_local_code_verifier` | Sol/xhigh; max for irreversible sign-off | read-only high-risk verification |
| Genuine evidence conflict or critical decision | `sol_advisor_final_adjudicator` | Sol/xhigh or max | read-only adjudication |

Reject Spark/xhigh, Context Luna/xhigh, Context Terra/high, Verifier Sol/medium or high,
and Adjudicator Sol/medium or high. If no allowed route fits, keep the work primary.

Investigator and Context Analyst are alternative discovery lanes for the same decision.
Mechanical Editor and Spark EDIT are mutually exclusive for the same batch. Do not add
a verifier merely because another child participated. Do not use Final Adjudicator as
a routine closing step or build a fixed role chain.

## Keep complex implementation primary

Do not delegate implementation that requires design or architecture judgment,
cross-module behavioral changes, public-interface or dependency changes, repeated
debugging, safety-critical implementation, or final integration. Spark and Mechanical
Editor may write only after the primary fixes the transformation, owned files,
preservation rules, edit count, and mechanical check.

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
adjudication remain serial.

## Spawn with a stable configuration

Use native Desktop collaboration with a unique task name, a minimal self-contained
message, and `fork_turns: "none"`.

- Pinned roles: Investigator/Luna, Mechanical Editor/Luna, Final Adjudicator/Sol, and
  Spark Worker/Spark. Pass `reasoning_effort`; omit redundant model overrides.
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

## Use inherited capabilities safely

Every child follows applicable `AGENTS.md` files and inherited parent instructions,
permissions, sandbox, MCP servers, Skills, web, and shell environment. Role
responsibility constrains side effects; it is not a tool allowlist. Never ask a child
to inventory, install, or reconfigure capabilities.

For repository relationships prefer Serena or CodeGraph when available; for exact
configuration or logs use exact text search and targeted reads; for versioned APIs use
official documentation or an inherited documentation capability. Missing indexes do
not block bounded exact-text investigation.

## Handle the native final

Every role returns `STATUS: COMPLETE | INCOMPLETE | BLOCKED` plus only its contract's
required fields and nonempty optional fields. Do not require a universal paragraph
layout. Treat the result as a claim:

- `COMPLETE` and usable: verify decisive evidence and integrate it.
- `INCOMPLETE` and correctable: send one same-child correction without changing model
  or effort.
- `BLOCKED`, unusable, or still incomplete after correction: take over immediately or
  report the genuine blocker.

Every child returns only one ordinary final response and ends immediately. It must not
send progress, status, or results through parent-interaction messaging and remain
active. Inspect detailed child history only for a concrete unusable-final or lifecycle
diagnosis.

Do not create a dispatch plan, run directory, `state.json`, pending record, response
token, result path, visible result copy, runtime copy, or machine sidecar. Do not use
Python or another script to accept, reject, or retry a child's natural-language result.
Native child state and its ordinary final are the runtime lifecycle source of truth.
Development-time static validation of TOML, routing, prompts, installers, and fixtures
is allowed and does not participate in dispatch.

## Bound final ownership

- Use zero children for the fast path and one child by default.
- Use at most two concurrent children, only for independent read-only work.
- Allow at most one corrective follow-up per child.
- Keep all writes serial and inspect their complete diffs.
- Do not let children spawn descendants.
- Keep complex implementation, final verification, integration, and the user response
  in the primary session.
