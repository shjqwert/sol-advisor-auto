# Functional agent contracts

Read only the selected role contract. Send the exact required fields in the listed
order, followed by any task-specific project constraints. Do not send conversation
history, raw source contents, or the primary's reasoning when locators are sufficient.

## Common lifecycle

Every child:

- follows applicable `AGENTS.md` files and inherited parent instructions;
- stays inside the supplied scope and stop conditions;
- does not create or manage other agents;
- returns one ordinary final response and ends immediately;
- sends no progress, status, or result through parent-interaction messaging;
- uses `STATUS: COMPLETE | INCOMPLETE | BLOCKED`; and
- omits empty optional fields, raw logs, tool narration, progress, and repetition.

Do not require a response token, result path, sidecar, plugin-owned state, universal
return mode, task-understanding paragraph, or fixed nine-heading result. Completeness
overrides the soft output budget.

## Investigator

Use `sol_advisor_investigator` with Luna/high for straightforward bounded discovery,
Luna/xhigh for cross-module search or official-source reconciliation, and Luna/max for
deep, incomplete, or high-stakes evidence.

~~~text
DECISION: <one decision this evidence can change>
QUESTION: <one repository or official-research question>
SEARCH_SCOPE: <exclusive paths, symbols, sources, and exclusions>
VERSION_DATE_BOUNDARY: <applicable version and date boundary, or none>
REQUIRED_EVIDENCE: <paths, symbols, direct links, dates, or applicability>
DONE_WHEN: <coverage and reconciliation required for COMPLETE>
STOP: <ambiguity, unsafe probe, expansion, or blocker condition>
~~~

Required final fields: `STATUS`, `ANSWER`, `EVIDENCE`.

Optional when nonempty: `FINDINGS`, `UNKNOWNS`.

Soft budget: 600-1400 characters. Remain read-only. Prefer static evidence and do not
run a test or probe unless explicitly required and guaranteed artifact-free.

## Context Analyst

Use `sol_advisor_context_analyst` with Luna/high for identified long-source extraction
or limited summary, Terra/xhigh for cross-module synthesis or conflicting constraints,
and Terra/max only for critical cross-module constraints. Escalate a genuine unresolved
evidence conflict to Final Adjudicator.

~~~text
DECISION: <one decision this synthesis can change>
QUESTION: <one identified-source question>
SOURCES: <exclusive files, logs, documents, modules, and sections>
SYNTHESIS_REQUIRED: <extraction, limited summary, or cross-source comparison>
CONFLICT_RULE: <how to report or escalate conflicting evidence>
DONE_WHEN: <constraints, coverage, and distinctions required for COMPLETE>
STOP: <unknown-location expansion, unrelated summary, or blocker condition>
~~~

Required final fields: `STATUS`, `SYNTHESIS`, `SOURCE_LOCATORS`.

Optional when nonempty: `CONSTRAINTS`, `CONFLICTS`, `UNCERTAINTY`.

Soft budget: 900-2200 characters. Remain read-only and distinguish evidence from
inference.

## Mechanical Editor

Use `sol_advisor_mechanical_editor` with Luna/xhigh or max only for one fully determined
transformation repeated across known locations. Do not use it for one focused local
behavior-production goal, and never share the same edit batch with another writer.

~~~text
TRANSFORMATION: <exact deterministic transformation>
OWNED_FILES: <exclusive path list>
REPETITION_SCOPE: <known locations or file classes receiving the same transformation>
PRESERVE: <interfaces, formatting, and unrelated work to preserve>
CHECK: <exact mechanical command and expected result>
DONE_WHEN: <all edits and checks required for COMPLETE>
STOP: <judgment, architecture, dependency, shared-file, or expansion condition>
~~~

Required final fields: `STATUS`, `CHANGED_FILES`, `CHECK`.

Optional when nonempty: `RESULT`, `DEVIATIONS`.

Soft budget: 500-1200 characters. Capture the pre-spawn worktree state. The primary
must inspect the complete actual diff and rerun CHECK after return.

## Local Code Verifier

Use `sol_advisor_local_code_verifier` with Luna/high for routine deterministic checks,
Luna/xhigh for multiple edge cases, or Luna/max for difficult bounded uncertainty. Use
Sol/xhigh for security, authorization, concurrency, state, data, migration, public-API,
or release risk, and Sol/max only for irreversible or system-level sign-off.

~~~text
CLAIM: <implementation or verification claim to attack>
SCOPE: <exclusive files, tests, and interfaces>
ATTACK_ANGLE: <one independent failure class>
PASS_FAIL_CRITERIA: <what establishes pass, fail, incomplete, or blocked>
REQUIRED_EVIDENCE: <trigger, impact, locator, test, or checked no-finding scope>
STOP: <scope expansion, write requirement, evidence conflict, or blocker condition>
~~~

Required final fields: `STATUS`, `VERDICT`, `EVIDENCE`, `COVERAGE`.

Optional when nonempty: `FINDINGS`, `TEST_GAPS`.

Soft budget: 700-1800 characters. Remain read-only, do not inspect another verifier's
conclusion, do not implement fixes, and do not adjudicate conflicting evidence.

## Final Adjudicator

Use `sol_advisor_final_adjudicator` with Sol/xhigh or max only for a genuine evidence
conflict or critical decision. Do not use it as a routine closing step.

~~~text
DECISION: <ship, fix-first, or rethink question>
CONFLICTING_CLAIMS: <compact claims that cannot all be true>
EVIDENCE_LOCATORS: <decisive locators for every supplied claim>
CONSTRAINTS: <safety, compatibility, reversibility, and release constraints>
STOP: <missing decisive evidence, new investigation, or implementation condition>
~~~

Required final fields: `STATUS`, `VERDICT`, `DECISIVE_EVIDENCE`,
`REJECTED_ASSUMPTIONS`, `REQUIRED_ACTION`.

Soft budget: 700-1600 characters. Remain read-only, consider every supplied branch,
and choose exactly `SHIP`, `FIX_FIRST`, or `RETHINK`.

## Spark Worker: PRODUCE

Use `sol_advisor_spark_worker` with Spark/low for template filling, simple declarations,
or one small artifact; Spark/medium for a focused local code change and its specified
check; or Spark/high for a larger output serving the same frozen local goal. High
effort does not compensate for incomplete facts, uncertain behavior, or design work.
Use no Spark/xhigh route.

~~~text
MODE: PRODUCE
GOAL: <one frozen local production goal>
OWNED_FILES: <exclusive paths that may be created or modified>
INPUT_FACTS: <confirmed facts that require no reinterpretation>
REFERENCE_LOCATORS: <small set of exact files or symbols the child may read>
ACCEPTANCE: <mechanically decidable behavior or output requirements>
PRESERVE: <interfaces, formatting, unrelated work, and existing changes>
CHECK: <exact mechanical command and expected result>
DONE_WHEN: <all output and check conditions required for COMPLETE>
STOP: <search, design, architecture, public-API, dependency, security, authentication,
concurrency, state, data-migration, cross-module, expansion, or repeated-debugging condition>
~~~

Required final fields: `STATUS`, `CHANGED_FILES`, `CHECK`.

Optional when nonempty: `DEVIATIONS`, `UNVERIFIED`.

Soft budget: 400-900 characters. Capture the pre-spawn worktree state, read only the
named owned files and reference locators, and do not search unknown locations or
interpret long material. If CHECK fails and correction requires broader search,
redesign, or continuing debugging, return `INCOMPLETE` or `BLOCKED`. The primary must
inspect the complete actual diff and rerun CHECK after return.

## One corrective follow-up

Use one follow-up only when the result is directionally correct and one bounded
omission prevents completion. Keep the same child, model, and effort.

~~~text
CORRECTION: <one exact misunderstanding or omission>
MISSING_EVIDENCE: <specific locator, source, check, or comparison>
KEEP: <correct prior work that must not be repeated>
STOP: <condition requiring primary takeover or a new stronger child>
~~~

Do not follow up for formatting alone, a wrong role, an unsafe route, or a task that
must be decomposed again. After one unusable correction, the primary takes over.
