---
name: orchestration
description: "Automatically activate Sol Advisor only when a repository task is likely to benefit from bounded delegation: broad or multi-module search, current external research, long logs or documents, deterministic bulk edits, material implementation uncertainty, critical risk, or independent adversarial verification. Keep complex implementation in the primary Codex session. Do not activate for bounded single-module implementation or debugging the primary can inspect directly, trivial one-step questions, simple formatting, casual explanation, or work where delegation cannot reduce context, latency, or verification risk."
---

# Sol Advisor Orchestration

Keep requirements, architecture, ambiguous reasoning, complex implementation, final
verification, and integration in the primary session. Delegate only a bounded question
that can run independently or materially reduce noisy context. A valid decision may use
no child agent.

## Authorize implicit delegation

When this Skill activates implicitly, spawn no child unless both independent project
signals are present:

- the nearest project root contains `.agent/authorizations.json` matching schema v1
  with `authorizations.solAdvisor.implicitDelegation` exactly `true`; and
- the applicable project-context managed section in `AGENTS.md` contains the
  corresponding `## Subagent Orchestration` authorization instruction.

Treat a missing, unreadable, invalid, false, or unfamiliar authorization file, or a
missing managed AGENTS instruction, as no implicit authorization. Continue in the
primary session without blocking ordinary work. Do not infer consent from plugin
installation, Skill activation, task complexity, or either project signal alone.

An explicit user request to use Sol Advisor, including an explicit plugin or Skill
invocation, bypasses the project authorization gate for that task. An explicit user
instruction not to delegate always overrides both project authorization and explicit
invocation. If a required Sol Advisor role is unavailable, keep the work in the primary
session without substituting another role or model.

Before the first spawn, read
[references/role-contracts.md](references/role-contracts.md). Load only the role
contract needed for the next child.

## Inherit project rules and capabilities

Every child follows the `AGENTS.md` instructions applicable to its working directory,
plus the parent task's active system, developer, sandbox, permission, and project rules.
Include the relevant task-specific constraints in the child message when isolated
context is used.

Custom-agent profiles deliberately omit `mcp_servers`, `skills.config`, `web_search`,
and shell-environment overrides. The child therefore uses inherited MCP servers,
Skills, and other tools from the parent runtime. Sol Advisor defines no capability
allowlist or denylist. Role instructions constrain responsibility and side effects,
not which inherited read or analysis capability the child may use.

Do not ask a child to inventory its tools. If a useful inherited capability is missing
or fails, the child uses another relevant inherited capability or reports the concrete
blocker. Never install or reconfigure MCP servers, Skills, or plugins as part of a
delegated task unless the user explicitly requested that change.

## Decide whether to delegate

Use no child when the primary already has sufficient evidence or the implementation
requires continuous design judgment. Otherwise choose the role from the task's main
nature:

### Fast path: keep bounded work in the primary

Use zero children when all of these are true:

- the relevant files, module, interface, or exact local scope are already known;
- requirements and success criteria are explicit and do not conflict;
- the primary can inspect the necessary context without broad search, long-source
  synthesis, or noisy-log reduction;
- the change is not a listed multi-file deterministic transformation that a mechanical
  editor can complete independently and verify mechanically;
- the task does not explicitly request an independent boundary-condition or test-gap
  attack; and
- ordinary primary verification is sufficient because no material implementation,
  compatibility, safety, or release uncertainty remains.

Do not delegate merely because the Skill activated, the task has several steps, or a
child role could perform part of the work. If the primary can complete the bounded task
directly, proceed in the primary session.

The fast path does not apply when the requested evidence is deliberately outside the
primary's bounded context. In particular:

- use Investigator for an unknown-location, cross-module call path or impact search;
- use Investigator for current official documentation that must be reconciled with
  local API usage and cited from direct sources;
- use Mechanical Editor for an exact transformation over an explicit list of two or
  more files when preservation rules and a mechanical check are supplied; and
- use Local Code Verifier when the user explicitly requests an independent read-only
  boundary-condition or test-gap attack on an implementation claim.

These signals select a bounded lane; they do not justify a fixed chain or an additional
child after that lane has answered its question.

### Select one lane before adding another

Investigator and Context Analyst are alternative discovery lanes for one question:
use Investigator when evidence locations are unknown or external facts must be found;
use Context Analyst when the sources are already identified but long, cross-module, or
constraint-heavy. Never call both to answer the same question.

Mechanical Editor is an execution lane only after the primary has fixed the exact file
list, transformation, preservation rules, and mechanical check. Do not add a verifier
merely because another child participated or edited files. Add Local Code Verifier only
when substantive implementation or boundary uncertainty remains after primary checks.

Use Final Adjudicator only for a genuine unresolved evidence conflict or critical-risk
decision. Do not use it as a routine closing step. Any later child must answer a distinct
new decision that the earlier child did not answer; never build a fixed role chain.

| Scenario | Agent | Model / effort | Responsibility |
|---|---|---|---|
| Repository search, precision lookup, or current external research | `sol_advisor_investigator` | Luna / xHigh; Max for deep work | bounded investigation, no edits |
| Long documents, logs, broad context, or cross-module constraints | `sol_advisor_context_analyst` | Terra / High, xHigh, or Max | read-only context analysis |
| Fully determined bulk or repetitive edits | `sol_advisor_mechanical_editor` | Luna / xHigh; Max for deep work | bounded serial edits |
| Independent implementation, boundary, or test-gap review | `sol_advisor_local_code_verifier` | Luna / Max | read-only local verification |
| Genuine evidence conflict or critical-risk decision | `sol_advisor_final_adjudicator` | Sol / Medium, xHigh, or Max | read-only final adjudication |

Use Context Analyst effort by context load and reasoning difficulty:

- `high`: bounded long-context extraction or summarization;
- `xhigh`: synthesis across long sources or several related modules;
- `max`: difficult cross-module constraints, critical verification, or conflicting
  evidence.

Use Sol Medium for a bounded low-impact dispute, xHigh for critical code or interface
risk, and Max for an architecture rethink, irreversible action, or severe evidence
conflict. Keep complex implementation in the primary session even when a child gathers
supporting evidence.

## Search capabilities

Choose tools by intent from the inherited capability set:

| Intent | Preferred route | Fallback |
|---|---|---|
| symbol, definition, reference | Serena, then CodeGraph | exact text search and targeted reads |
| call path, impact, architecture | CodeGraph, then Serena | exact text search and targeted reads |
| exact text, configuration, logs | exact text search | targeted reads |
| local PDF or Office document | MarkItDown | inherited document/PDF Skill |
| versioned library/API documentation | Context7 | official documentation, then web search |
| current external fact or known page | built-in web, then Exa | primary-source browser retrieval |

Do not deny repository investigation merely because CodeGraph or Serena has no current
index. When indexing is authorized and a broad local question needs it, the primary may
run the repository preflight before spawning:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
python_runner="$skill_dir/../../scripts/run-python.sh"
search_preflight="$skill_dir/../../scripts/prepare-repo-search.py"
sh "$python_runner" "$search_preflight" <repository-root> \
  --indexing create-if-missing --apply
~~~

Index preparation belongs to the primary session. Inspect tracked changes before and
after, never stage generated metadata automatically, and fall back to exact text search
and targeted reads when an index tool is unavailable.

## Spawn natively

Use Desktop native collaboration so the child remains visible. Send:

- the selected `agent_type`;
- a unique, descriptive `task_name`;
- a self-contained bounded `message`;
- `fork_turns: "none"`;
- the selected `reasoning_effort`.

Each role file pins its base model. Omit a model override for the pinned base model.
If the required role, model, or reasoning strength is unavailable, keep the work in
the primary session instead of substituting an unapproved route.

Tell every child to return its result only as the ordinary final response and end the
turn immediately. The child must not send progress, status, or results through
parent-interaction messaging and then remain active. The primary waits for the native
final result; it does not treat an interim interaction message as task completion.

Do not create a dispatch plan, run directory, `state.json`, pending record, response
token, result path, visible copy, runtime copy, or machine sidecar. Do not run Python to
validate the plan or child result. Codex native child status and the ordinary returned
result are the lifecycle source of truth.

## Handle the returned result

Treat child output as a claim and classify it in the primary session:

1. `usable`: integrate it and verify any decisive evidence needed for the task.
2. `correctable`: the direction is sound but a bounded omission, misunderstanding, or
   missing locator can be repaired. Send one targeted native follow-up to the same
   child, preserving its existing context.
3. `unusable`: the role or direction is wrong, the result is empty or generic, a tool
   is blocked, or recovery would require redoing the task. The primary executes the
   work directly.

Allow at most one corrective follow-up per child. If the follow-up is still unusable,
the primary takes over immediately. Do not restart the same child from scratch, create
a retry state file, or loop until a format passes.

## Bound delegation

- Fast-path work uses zero children.
- Use one child by default.
- Use at most two concurrent children, only for independent read-only questions with
  distinct attack angles.
- Prefer one discovery lane. Add another child later only for a distinct unresolved
  decision whose expected quality or context benefit exceeds its startup and wait cost.
- Keep shared files, dependency chains, mechanical edits, follow-ups, and adjudication
  serial.
- No child may spawn descendants.
- Subagent use may reduce primary-context noise while increasing total tokens; keep
  questions narrow and never claim token savings without a controlled comparison.

## Verification and adjudication

After primary implementation and primary verification:

1. Finish low-risk work when no material uncertainty remains.
2. For substantive uncertainty, use one Luna/Max local verifier.
3. For critical risk, use Luna/Max local verification and Terra/Max cross-module
   analysis with distinct attack angles when both add independent evidence.
4. Reproduce only findings that can change implementation or delivery.
5. Fix clear defects in the primary session and rerun the minimum relevant checks.
6. Use the Sol adjudicator only for a genuine remaining evidence conflict or critical
   decision.

Always inspect the actual diff after a mechanical edit. Child results are advisory;
the primary owns the final decision, validation, and user response.
