---
name: orchestration
description: "Use for engineering work: long sources, unknown search, focused production, frozen plans, or independent adversarial review. Delegate clear bounded role matches with quality first; zero children is valid."
---

# Sol Advisor Orchestration

Completion quality comes first, then end-to-end time. Reduce quota and context
cost only within the required quality boundary. Keep requirements, architecture,
unresolved design, integration and the final user response in the primary.

## Recognize a bounded task

A clear role match positively selects delegation when its scope, owner, adequate
model and completion condition are known. A quick exact lookup stays local.
Do not load every role contract to decide whether a task can be delegated.

| Task | Role |
|---|---|
| Compact frozen local production | `sol_advisor_spark_worker` |
| Unknown-location investigation | `sol_advisor_investigator` |
| Identified long sources or cross-module synthesis | `sol_advisor_context_analyst` |
| Frozen detailed implementation in named files | `sol_advisor_mechanical_editor` |
| Authorized frozen ordered test plan | `sol_advisor_test_executor` |
| Concrete implementation or verification claim | `sol_advisor_local_code_verifier` |
| Decision-level independent review or conflict | `sol_advisor_final_adjudicator` |

An upstream required independent review goes to its reviewer; do not repeat its
admission decision. RAG retrieval alone does not create a child stage. Ordinary
local edits do not require adversarial review.

## Route only when needed

Before the first spawn, read [routing.md](references/routing.md) for policy,
model/effort selection and ownership. Then read the common
[contract index](references/role-contracts.md) and load exactly one selected file
under `references/roles/`. Respect opt-outs and unavailable native capabilities.
Use zero children for a bounded direct lookup or when the required route is unavailable.

Applicable AGENTS.md supplies project rules, Agent TOML supplies role boundaries,
and dispatch supplies task-local scope. Keep these layers distinct and preserve
nested project rules without copying the entire project file into every packet.

## Dispatch and integrate

Give each task one owner and name the primary's disjoint work. Parallelism follows
dependencies and exclusive files/resources, with no fixed child-count default or
cap; native runtime limits still apply. Conflicting writers and device operators
remain serial.

After dispatch, do not repeat the child-owned investigation or edits. Read its
ordinary final response once, inspect decisive evidence and edited diffs, then
integrate. Use one corrective follow-up for a concrete omission, or end the child's
ownership before primary takeover. Do not rerun its complete task.

Children return one native final response and end; no progress or results through
parent-interaction messaging. Use native completion state, not a sidecar or a
daily routing diagnostic. For detailed resume and adversarial finding disposition,
follow the selected role and routing reference.
