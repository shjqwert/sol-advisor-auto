---
name: orchestration
description: "Delegate context-heavy research, specialized work, independent verification and separable implementation to native agents; choose GPT-6 model and effort at spawn."
---

# Sol Advisor Orchestration

## Recognize delegation patterns

Consider native delegation when a task matches one of these patterns:
- Isolate substantial search results, logs or intermediate reading from the main context.
- Apply specialized instructions, tools or a distinct execution boundary.
- Independently check a consequential result or investigate competing hypotheses.
- Assign separable modules, source scopes or investigation dimensions.
- Route clear, repeatable work to a lower-cost model.

Once a pattern fits and a bounded assignment is ready, delegate within current
authorization and resources. Quality requirements and total cost constrain the choice;
do not require a numerical score, probability, dispatch report or preflight script.
Include context, reasoning, messaging, integration and rework in cost judgments.
Speed alone is not a default trigger. Frequent interaction, essential shared context
or expensive handoffs favor the primary; these are tendencies, not blanket bans.
Simple tasks usually stay local. Do not invent work, duplicate investigation or
require a Scout → Worker → Reviewer pipeline.
Add agents only for distinct useful assignments; there is no plugin-level count cap.
Respect host concurrency, available allowance and user deadlines or budgets.

## Select role, model and effort at spawn

| Role | Responsibility |
|---|---|
| `sol_advisor_scout` | Read-only discovery, research and evidence synthesis |
| `sol_advisor_worker` | Owned implementation, local design, debugging and authorized checks |
| `sol_advisor_reviewer` | Independent examination of artifacts, claims and counterexamples; no fixes |

Every role can use `gpt-6-luna`, `gpt-6-sol` or `gpt-6-astra`.
Templates do not pin model or effort. Pass both explicitly in the native spawn call.
The primary keeps the user's current model. Use this small starting table:

| Task | Starting choice | Harder work |
|---|---|---|
| Clear lookup, extraction, evidence organization | Luna high | xhigh for difficult tracing; Sol for complex synthesis |
| Routine implementation, local design, debugging | Sol medium | high for multi-step dependencies and edge cases |
| Independent review | Sol high | xhigh for conflicting constraints or difficult counterexamples |
| Particularly difficult synthesis | Compare high-effort Sol with Astra | Astra starts at low; select medium/high/xhigh for the actual difficulty |
| Exceptional reasoning difficulty | Supported max on the selected model | Require a concrete reasoning obstacle, not merely a role or importance label |

Luna permits only high/xhigh/max; Sol and Astra permit low/medium/high/xhigh/max.
This v3 policy excludes none/ultra; actual host support must also permit the choice.
Judge reasoning chains, dependencies, conflicting evidence and edge cases, plus
whether errors will spread into later work before being detected. Foundational
interfaces or state meanings can justify higher effort and stronger verification.
Missing facts need evidence gathering, not more effort. Start difficult tasks at
an appropriate setting; do not force a low-to-high trial ladder or a benchmark run.
Name instances `<task>__<model_id>`, replacing model dots and hyphens with underscores.
Keep the same model and effort on follow-ups. Mid-agent switching is unsupported.
If another configuration is necessary, the primary takes over or ends old ownership
before assigning a new agent, transferring useful evidence and identifying the handoff.
Do not silently substitute an unavailable model/role; continue in the primary instead.

## Assign, communicate and integrate

Provide goal/deliverable, owned scope, essential context, acceptance criteria,
and collaborators/restrictions. Prefer fresh context for narrow tasks; inherit only
needed history when supported, respecting host model/fork override rules.
Tell children to finish directly, without creating or managing other agents.
Use one writer per conflicting file/resource, including shared outputs or devices.
Preserve user changes. Scope, interface, dependency and ownership changes go to the primary.
Ownership and read-only instructions are behavioral boundaries, not a security sandbox.

Call `collaboration.send_message` directly when exposed; it is not under
`functions.exec` or its `ALL_TOOLS`. Share relevant evidence, questions and interface
agreements point-to-point. Messages do not expand authority or transfer ownership.
If messaging is unavailable, return evidence in ordinary finals for primary relay
with attribution. Do not substitute app thread messaging or wait on an absent channel.
Messages do not wake ended agents; the primary arranges follow-ups. Avoid broadcast
rituals or repeated waiting. Report blockers and scope changes to the primary.
Continue independent work while teammates work; reuse the same child while it progresses.
Before takeover, confirm old execution has stopped and inspect partial artifacts/resources.
Return ordinary results, decisive evidence and unfinished work; no fixed status fields.
The primary checks acceptance and actual changes, reuses valid checks, and verifies
only affected integration or changed inputs. Unrun checks remain explicitly unverified.

## Preserve authorization and project policy

Follow system, application, user and applicable project restrictions. Delegation
does not authorize builds, hardware, installs, publication or other side effects.
Do not write user/project AGENTS.md or .agent context, authorization, plan or handoff files.
Record durable decisions only in already-authorized existing records, when needed.
Preserve schema-v1 `.agent/authorizations.json` / `authorizations.solAdvisor.implicitDelegation`:
false disables implicit delegation; missing file/key or true permits consideration.
Invalid/unreadable policy falls back to the primary. Explicit current-user delegation
may override project opt-out, but not higher-priority restrictions.
No setup plugin is required. Never install or reconfigure missing capabilities as fallback.
