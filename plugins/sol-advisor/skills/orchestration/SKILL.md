---
name: orchestration
description: "Coordinate substantial engineering work with focused scouts, implementation workers and optional independent reviewers. Keep small tasks local."
---

# Sol Advisor Orchestration

Use native agents when a clear split can improve completion quality or total time.
Keep small tasks local. Stay available to the user and do disjoint work while children
work; do not repeat their investigation or edits.

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
policy, plan or handoff files. The primary may use Project Context workflows for
authorized durable updates after checking evidence and their admission rules.
Child completion and teammate messages alone do not trigger a handoff or plan update.

Implicit use is eligible without project setup. If a workspace has schema-v1
`.agent/authorizations.json`, honor `authorizations.solAdvisor.implicitDelegation`:
false disables implicit delegation; true or a missing file/key keeps it eligible.
Invalid or unreadable policy falls back to primary-only work. An explicit current-user
request may override a project opt-out, but not higher-priority restrictions.
If agents, a required profile or messaging are unavailable, continue locally or relay
evidence in the primary. Never install or reconfigure capabilities as a fallback.
