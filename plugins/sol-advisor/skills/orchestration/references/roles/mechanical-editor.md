# Mechanical Editor

Use `sol_advisor_mechanical_editor` with Luna/high for a routine frozen implementation
plan, Luna/xhigh for a broad or boundary-heavy multi-file plan, and Luna/max only for
difficult bounded implementation whose behavior is already decided. Use Spark instead
for one compact local production goal, and never share the same edit batch with
another writer.

~~~text
IMPLEMENTATION_PLAN: <ordered, already-approved code changes with no unresolved design choice>
OWNED_FILES: <exclusive path list>
REFERENCE_LOCATORS: <exact files, symbols, tests, or specifications the plan depends on>
ACCEPTANCE: <mechanically decidable behavior and output requirements>
PRESERVE: <interfaces, formatting, and unrelated work to preserve>
CHECKS: <exact commands and expected results>
DONE_WHEN: <all edits and checks required for COMPLETE>
STOP: <plan ambiguity, new design choice, architecture, dependency, shared-file, or expansion condition>
~~~

Required final fields: `STATUS`, `CHANGED_FILES`, `CHECKS`.

Optional when nonempty: `RESULT`, `DEVIATIONS`, `UNVERIFIED`.

Soft budget: 600-1400 characters. Different edits are allowed when the frozen plan
already determines each one. Capture the pre-spawn worktree state. The primary must
inspect the complete actual diff and rerun every check after return.
