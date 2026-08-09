# Functional agent contracts

Use the smallest self-contained contract that lets one child answer one bounded
question. Every child message states:

- the exact question and scope;
- the decision the result can change;
- relevant exclusions and side-effect boundaries;
- the expected evidence;
- the stop condition;
- that applicable `AGENTS.md` rules and inherited parent MCP and Skill capabilities
  remain available.

Do not require a response token, result path, JSON sidecar, fixed Markdown schema, or
plugin-owned state. The child returns one ordinary concise result through Codex native
collaboration. The primary judges its usefulness and verifies decisive evidence.

Every child returns its result only as its ordinary final response and ends the turn
immediately. It must not send progress, status, or results through parent-interaction
messaging, then continue running. A blocker is also a final response, not an interim
message.

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
QUESTION: <one repository or external-research question>
SCOPE: <paths, symbols, sources, date/version boundaries, and exclusions>
DECISION: <what this can change>
EXPECTED EVIDENCE: <paths, symbols, tests, direct links, dates, or applicability>
PROJECT RULES: follow applicable AGENTS.md and inherited parent instructions.
CAPABILITIES: use any relevant inherited MCP or Skill; do not inventory tools.
STOP: remain read-only and return concise findings, unknowns, or no finding.
~~~

## Context Analyst

Use `sol_advisor_context_analyst` with Terra/High for bounded long-context extraction,
Terra/xHigh for synthesis across long sources or related modules, and Terra/Max for
difficult cross-module constraints or critical independent verification.

~~~text
QUESTION: <one long-context or cross-module question>
SOURCES: <bounded files, logs, documents, modules, and exclusions>
DECISION: <what this can change>
EXPECTED EVIDENCE: <source locations and observation/inference distinction>
PROJECT RULES: follow applicable AGENTS.md and inherited parent instructions.
CAPABILITIES: use any relevant inherited MCP or Skill; do not inventory tools.
STOP: remain read-only and omit unrelated summary.
~~~

## Mechanical Editor

Use `sol_advisor_mechanical_editor` with Luna/xHigh for a standard deterministic edit
or Luna/Max for a deep but still fully determined edit. Never share its batch with
another editing route.

~~~text
CHANGE: <exact transformation>
FILES: <exclusive path list>
PRESERVE: <interfaces and unrelated edits>
VERIFY: <exact command and expected result>
PROJECT RULES: follow applicable AGENTS.md and inherited parent instructions.
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
PROPOSED BEHAVIOR: <claim being attacked>
ATTACK ANGLE: <one failure class>
SCOPE: <files, interfaces, evidence, and exclusions>
EXPECTED EVIDENCE: <trigger, impact, location/test, or checked no-finding scope>
PROJECT RULES: follow applicable AGENTS.md and inherited parent instructions.
CAPABILITIES: use any relevant inherited MCP or Skill; do not inventory tools.
STOP: remain read-only and do not implement.
~~~

## Final Adjudicator

Use `sol_advisor_final_adjudicator` only for a genuine evidence conflict or critical
decision. Use Sol/Medium for a bounded dispute, Sol/xHigh for critical code or interface
risk, and Sol/Max for architecture rethink, irreversible action, or severe conflict.

~~~text
DECISION: <ship, fix-first, or rethink question>
EVIDENCE: <compact conflicting claims with locators>
CONSTRAINTS: <safety, compatibility, reversibility, and exclusions>
PROJECT RULES: follow applicable AGENTS.md and inherited parent instructions.
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
