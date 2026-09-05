# Mechanical Editor

Use `sol_advisor_mechanical_editor` with Luna/high for a routine frozen implementation
plan, Luna/xhigh for a broad or boundary-heavy multi-file plan, and Luna/max only for
difficult bounded implementation whose behavior is already decided. Spark remains
optional for explicit requests or concrete low-latency benefit. Never share the same
edit batch with another writer.

~~~text
IMPLEMENTATION_PLAN: <ordered, already-approved code changes with no unresolved design choice>
OWNED_FILES: <exclusive path list>
REFERENCE_LOCATORS: <exact files, symbols, tests, specifications, and selected applicable coding Skill/rule locators>
ACCEPTANCE: <mechanically decidable behavior and output requirements>
PRESERVE: <interfaces, key applicable coding constraints, formatting, and unrelated work>
CHECKS: <exact commands and expected results>
DONE_WHEN: <all edits and checks required for COMPLETE>
STOP: <plan ambiguity, new design choice, architecture, dependency, shared-file, or expansion condition>
~~~

Required final fields: `STATUS`, `CHANGED_FILES`, `CHECKS`.

Optional when nonempty: `RESULT`, `DEVIATIONS`, `UNVERIFIED`.

Soft budget: 600-1400 characters. Different edits are allowed when the frozen plan
already determines each one. Capture the pre-spawn worktree state. The primary must
inspect the complete actual diff and check evidence; repeat a check only for a
concrete gap or invalidated result. The parent supplies selected applicable coding
Skill/rule locators and key constraints. The child reads those located coding
references; this is not unknown search. Frozen behavior never replaces user coding
requirements. Do not copy a whole Skill or add a fixed style-review pipeline.
