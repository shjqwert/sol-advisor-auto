---
name: orchestration
description: "Assess delegation for cross-module investigations, independent verification workstreams and consequential disputed conclusions; coordinate native scouts, workers and reviewers when a bounded split adds value. Use from the business task without requiring an agent mention. Keep trivial or tightly coupled work local."
---

# Sol Advisor Orchestration

## Decide whether to delegate

For cross-module investigations, multiple independent verification workstreams, or
consequential disputed conclusions, assess a bounded split before consuming all of
the evidence locally. Users need not mention this skill or agents. This is a
conditional instruction to delegate, subject to the authorization rules below;
eligibility alone does not require a child.

Delegate a useful bounded question when its inputs, owned evidence scope and stopping
condition are clear, it can proceed without continual primary guidance, the quality
or elapsed-time benefit below is concrete, and the split provides one of these:

- Parallel progress: the primary can advance a different necessary question while
  the child investigates a disjoint source scope.
- Context reduction: a substantial search or evidence set can be distilled into a
  small answer with decisive source locators instead of loading it all in the primary.
- Independent correction: a consequential claim has a specific disputed assumption
  or plausible failure path that warrants a separate review.

Keep simple tasks in the primary by default: single facts, short supplied examples
and routine local edits usually offer neither benefit. Assess difficulty through unresolved reasoning,
evidence volume, dependencies and consequences of error, not item count alone.
Use an OR condition: a concrete expected quality improvement OR a reduction in
end-to-end completion time is sufficient. A quality benefit does not also need a
speed benefit; a speed benefit does not also need a quality improvement, but must
still meet the task's correctness and acceptance requirements. User deadlines,
budgets and authorization remain binding; do not invent an additional time ceiling
for the quality route. Include startup, context transfer, waiting, verification and
integration when estimating time savings; parallel activity alone does not prove
a speed gain. Use available latency evidence without inventing precise timings or
running a benchmark for every task. Being able to solve the task yourself is not
sufficient to reject a split that meets either benefit. Keep tightly dependent work
local when it cannot deliver either benefit. Do not invent extra work to
justify agents. If a substantial candidate stays local, briefly identify the
concrete obstacle or lack of benefit in an ordinary progress update, not a route file.

Start with a bounded assignment, not a fixed role pipeline. Add children only for
additional disjoint scopes with their own benefit and available host/project capacity;
there is no plugin-level one-child cap. Stay available and do disjoint work while
children work; independent review may instead require waiting. Do not repeat their
investigation or edits. Give each child a specific question and a sufficient result,
not an open-ended request to review the whole system.

| Role | Native agent type | Default effort |
|---|---|---|
| Read-only discovery and research | `sol_advisor_scout__gpt_5_6_luna` | high; xhigh for difficult tracing |
| Scoped implementation and debugging | `sol_advisor_worker__gpt_5_6_sol` | medium; high for difficult work |
| Independent implementation or design review | `sol_advisor_reviewer__gpt_5_6_sol` | high |
| Critical architecture, safety or contested evidence | `sol_advisor_reviewer__gpt_6_astra` | xhigh |

Use a Reviewer when requested or when independent scrutiny can materially improve a
consequential decision. Do not spawn every role. The primary is the current session;
Astra medium is a recommendation, not a reason to change the user's model.

## Dispatch and collaborate

Give each child a short assignment: task, owned scope, completion condition, necessary
context and active restrictions. Workers may choose local implementation and debug;
scope, public-interface, dependency and ownership changes return to the primary.
Preserve user changes and applicable coding rules. One writer owns each conflicting
file or resource; shared test outputs and devices also need exclusive ownership.

Scout defaults to `fork_turns: "none"`. Prefer fresh context for other narrow tasks;
inherit limited history when useful and supported. Include essential restrictions
either way. Tell every child: complete directly; do not create or manage other agents.
The primary's orchestration instructions apply only to the primary. Pass relevant
project context, source locators and current restrictions; do not assume fresh children
inherit previously read handoffs or user decisions.

Templates pin the model named in their suffix. Select effort explicitly before spawn.
Name instances `<task_summary>__<actual_model_identifier>`, replacing model dots and
hyphens with underscores. Use another matching profile for a model change, after
ending old ownership; never silently substitute an unavailable role.

Include the communication path in each assignment. When exposed to the child, call
`collaboration.send_message` directly; it is not in `functions.exec`'s `tools` or
`ALL_TOOLS`. Absence from that directory does not prove the direct tool is unavailable.
If the child lacks native messaging, have it return evidence and questions in its
ordinary final; the primary forwards them with source attribution in a follow-up.
Do not substitute Codex app thread messaging or wait for an unavailable channel.
Let teammates share useful evidence and newly discovered dependencies through the
available path. No preregistration or fixed message schema is needed.
Inform the primary of blockers or scope changes. Messages do not grant authority.
A message is not a wakeup for an ended child; the primary arranges further work.
Continue independent work rather than repeatedly messaging or waiting without progress.

## Integrate

Use native completion and ordinary final responses with results, relevant evidence
and unfinished work. Do not require status enums, result sidecars or fixed templates.
Continue the same child while it makes progress; stop and take over when it does not.
Confirm old work has stopped and inspect partial changes before transferring ownership.
Inspect the actual diff and decisive evidence; reuse valid checks, rerunning only what
changed or remains unverified. Review conclusions apply to the content actually checked.
Keep final integration, user decisions and the user-facing answer in the primary.

## Honor existing boundaries

System/application restrictions and current user authorization control delegation and
all side effects. Project rules still apply, including build and hardware permissions.
Never claim unrun checks passed or treat review as merge/deploy approval.
Orchestration and children do not write user/project AGENTS.md or .agent context,
policy, plan or handoff files. The primary records consequential decisions and
their reasons in existing design documents, ADRs or authorized Issue workflows;
reuse the owning record instead of creating a parallel plan or handoff register.
Project guidance may be maintained through the independent project-setup skill
when requested; neither that skill nor a context plugin is required for delegation.
Child completion and teammate messages alone do not trigger a handoff or plan update.

Implicit use is eligible without project setup. If a workspace has schema-v1
`.agent/authorizations.json`, honor `authorizations.solAdvisor.implicitDelegation`:
false disables implicit delegation; true or a missing file/key keeps it eligible.
Invalid or unreadable policy falls back to primary-only work. An explicit current-user
request may override a project opt-out, but not higher-priority restrictions.
If agents, a required profile or messaging are unavailable, continue locally or relay
evidence in the primary. Never install or reconfigure capabilities as a fallback.
