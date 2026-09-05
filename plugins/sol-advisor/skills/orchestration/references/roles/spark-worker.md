# Spark Worker: PRODUCE

Use `sol_advisor_spark_worker` with Spark/low for template filling, simple declarations,
or one small artifact; Spark/medium for a focused local code change and its specified
check; or Spark/high for a larger output serving the same frozen local goal. High
effort does not compensate for incomplete facts, uncertain behavior, or design work.
Use no Spark/xhigh route.

Use only for an explicit Spark request or concrete low-latency benefit. Ordinary
small edits stay primary. Quota exhaustion or unavailability ends child ownership;
the primary inspects existing changes and continues without waiting or repeated spawns.

~~~text
MODE: PRODUCE
GOAL: <one frozen local production goal>
OWNED_FILES: <exclusive paths that may be created or modified>
INPUT_FACTS: <confirmed facts that require no reinterpretation>
REFERENCE_LOCATORS: <exact files, symbols, and selected applicable coding Skill/rule locators>
ACCEPTANCE: <mechanically decidable behavior or output requirements>
PRESERVE: <interfaces, key applicable coding constraints, formatting, and existing changes>
CHECK: <exact mechanical command and expected result>
DONE_WHEN: <all output and check conditions required for COMPLETE>
STOP: <search, design, architecture, public-API, dependency, security, authentication,
concurrency, undecided state-machine, data-migration, hardware-control, cross-module
decision, expansion, or repeated-debugging condition>
~~~

Required final fields: `STATUS`, `CHANGED_FILES`, `CHECK`.

Optional when nonempty: `DEVIATIONS`, `UNVERIFIED`.

Soft budget: 400-900 characters. Capture the pre-spawn worktree state, read only the
named owned files and reference locators, and do not search unknown locations or
interpret long material. If CHECK fails and correction requires broader search,
redesign, or continuing debugging, return `INCOMPLETE` or `BLOCKED`. Decided simple
state updates and repeated transformations within exact owned files are allowed.
The primary inspects the complete actual diff and reported check evidence. Repeat
CHECK only for a concrete gap or invalidated result, under public routing rules.
The parent supplies selected applicable coding Skill/rule locators and key constraints.
The child reads these located coding references; this is not unknown search. Frozen
behavior never replaces user coding requirements. Do not copy whole Skills or add
a fixed style-review pipeline.
