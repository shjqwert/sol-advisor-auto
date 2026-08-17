# Mechanical Editor

Use `sol_advisor_mechanical_editor` with Luna/high for routine repeated exact changes,
Luna/xhigh for broad or boundary-heavy repetition, and Luna/max only for difficult
bounded repetition. Do not use it for one focused local behavior-production goal, and
never share the same edit batch with another writer.

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
