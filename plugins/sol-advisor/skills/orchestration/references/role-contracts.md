# Functional agent contracts

Use the smallest self-contained contract that lets one child answer one bounded
question. Every child message uses this common packet:

~~~text
DECISION: <one decision this result can change>
QUESTION: <one bounded question or deterministic change>
SCOPE: <exclusive paths, sources, versions, or interfaces>
EXCLUSIONS: <explicitly out-of-scope work and side effects>
EXPECTED_EVIDENCE: <decisive locators, checks, or direct sources>
COMPLETENESS: <what must be covered for STATUS COMPLETE>
STOP: <ambiguity, expansion, safety, or blocker condition>
RETURN_MODE: COMPACT | STANDARD | EXTENDED
PROJECT_RULES: follow applicable AGENTS.md and inherited parent instructions.
~~~

Do not require a response token, result path, JSON sidecar, or plugin-owned state. The
child returns one ordinary structured final through Codex native collaboration. The
primary judges its usefulness and verifies decisive evidence.

Every child returns its result only as its ordinary final response and ends the turn
immediately. It must not send progress, status, or results through parent-interaction
messaging, then continue running. A blocker is also a final response, not an interim
message.

## Common final response

Return exactly one final response with these headings:

~~~text
STATUS: COMPLETE | INCOMPLETE | BLOCKED
RETURN_MODE: COMPACT | STANDARD | EXTENDED
TASK_UNDERSTANDING: <one-sentence interpretation>
ANSWER/VERDICT: <direct answer or result>
DECISION-CHANGING FINDINGS: <only material findings>
EVIDENCE: <decisive locators or checks>
COVERAGE: <what was and was not covered>
UNCERTAINTY: <none, bounded unknowns, or blocker>
REQUIRED ACTION: <none or the minimum next action>
~~~

Treat length as a soft budget: `COMPACT` is normally 600-1200 characters,
`STANDARD` 1200-3000 characters, and `EXTENDED` begins with an approximately
1200-character decision summary followed by every finding needed for completeness.
Completeness overrides the budget; never omit decisive evidence merely to fit. Use no
more than three decisive locators in COMPACT or STANDARD unless correctness requires
more. Omit raw logs, large code excerpts, tool narration, progress, and repetition.

Use `COMPLETE` only when the packet's completeness condition is met, `INCOMPLETE` when
one bounded correction could complete it, and `BLOCKED` when evidence or permissions
prevent a reliable answer. State uncertainty instead of filling gaps with inference.

## Common capability rule

Role selection assigns responsibility; it does not create a tool allowlist or denylist.
Children may use any inherited MCP, Skill, search, document, or repository capability
that is relevant and permitted by the active parent and project rules. Read-only roles
remain behaviorally read-only, while the mechanical editor may modify only its assigned
files.

## Investigator

Use `sol_advisor_investigator` with Luna/xHigh for bounded repository discovery or
current external research. Use Luna/Max for precision search, difficult debugging,
multiple modules, incomplete evidence, high-stakes reconciliation, or conflicting
primary sources.

~~~text
<COMMON PACKET>
QUESTION: <one repository or external-research question>
SCOPE: <exclusive paths, symbols, sources, and date/version boundaries>
EXPECTED_EVIDENCE: <paths, symbols, direct links, dates, or applicability>
COMPLETENESS: <search coverage and reconciliation needed for COMPLETE>
CAPABILITIES: use any relevant inherited MCP or Skill; do not inventory tools.
STOP: remain read-only and return concise findings, unknowns, or no finding. Prefer
static evidence; do not run tests or runtime probes unless explicitly required and
guaranteed artifact-free, and never send an inline probe with shell redirection or
control metacharacters through a shell.
~~~

## Context Analyst

Use `sol_advisor_context_analyst` with Terra/High for bounded long-context extraction,
Terra/xHigh for synthesis across long sources or related modules, and Terra/Max for
difficult cross-module constraints or critical independent verification.

~~~text
<COMMON PACKET>
QUESTION: <one long-context or cross-module question>
SCOPE: <identified files, logs, documents, modules, and exclusions>
EXPECTED_EVIDENCE: <source locations and observation/inference distinction>
COMPLETENESS: <constraints, conflicts, and source coverage needed for COMPLETE>
CAPABILITIES: use any relevant inherited MCP or Skill; do not inventory tools.
STOP: remain read-only and omit unrelated summary.
~~~

## Mechanical Editor

Use `sol_advisor_mechanical_editor` with Luna/xHigh for a standard deterministic edit
or Luna/Max for a deep but still fully determined edit. Implicit use requires at least
four files, or at least twenty same-type edit points across two or more files. Never
share its batch with another editing route.

~~~text
<COMMON PACKET>
QUESTION: <exact deterministic transformation>
SCOPE: <exclusive path list and edit-point count>
EXCLUSIONS: <interfaces, paths, and unrelated edits to preserve>
EXPECTED_EVIDENCE: <actual changed files plus exact check and expected result>
COMPLETENESS: <all listed edit points changed and check satisfied>
CAPABILITIES: use any relevant inherited MCP or Skill within the edit scope.
STOP: if judgment, ambiguity, architecture, dependency expansion, or an out-of-scope
path is required, stop without further changes and report the blocker.
~~~

Capture the pre-spawn working-tree status. After return, inspect the actual diff, reject
out-of-scope changes, and rerun the minimum relevant check.

## Local Code Verifier

Use `sol_advisor_local_code_verifier` with Luna/Max for substantive implementation
uncertainty. Give it one independent attack angle and do not expose another verifier's
conclusion.

~~~text
<COMMON PACKET>
QUESTION: <implementation claim being attacked>
SCOPE: <exclusive files and interfaces>
EXCLUSIONS: <other failure classes and any proposed fixes>
ATTACK_ANGLE: <one independent failure class>
EXPECTED_EVIDENCE: <trigger, impact, location/test, or checked no-finding scope>
COMPLETENESS: <boundary and test-gap coverage needed for COMPLETE>
CAPABILITIES: use any relevant inherited MCP or Skill; do not inventory tools.
STOP: remain read-only and do not implement.
~~~

## Final Adjudicator

Use `sol_advisor_final_adjudicator` only for a genuine evidence conflict or critical
decision. Use Sol/Medium for a bounded dispute, Sol/xHigh for critical code or interface
risk, and Sol/Max for architecture rethink, irreversible action, or severe conflict.

~~~text
<COMMON PACKET>
DECISION: <ship, fix-first, or rethink question>
QUESTION: <genuine conflict to resolve>
SCOPE: <compact conflicting claims and their locators>
EXCLUSIONS: <unsupported history and implementation work>
EXPECTED_EVIDENCE: <decisive conflict resolution>
COMPLETENESS: <all supplied conflict branches considered>
CONSTRAINTS: <safety, compatibility, and reversibility>
CAPABILITIES: use any relevant inherited MCP or Skill; do not inventory tools.
RETURN: one verdict and the minimum decisive rationale and required action.
STOP: remain read-only and do not implement.
~~~

## One corrective follow-up

When the first result is directionally correct but misses one bounded requirement, use
the same native child once more:

~~~text
CORRECTION: <exact misunderstanding or omission>
MISSING EVIDENCE: <specific locator, source, check, or comparison required>
KEEP: <correct parts of the prior result that must not be redone>
RETURN: a revised concise result addressing only this correction.
STOP: if the correction cannot be completed with current context and capabilities,
state the blocker; do not restart the whole task.
~~~

Do not follow up when the role, direction, or task decomposition was wrong. In that
case, or when the one follow-up remains unusable, the primary session executes the
work directly.
