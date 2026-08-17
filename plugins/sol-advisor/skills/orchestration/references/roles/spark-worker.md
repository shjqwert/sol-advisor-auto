# Spark Worker: PRODUCE

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
