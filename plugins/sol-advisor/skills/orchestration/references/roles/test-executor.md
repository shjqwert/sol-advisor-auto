# Test Executor

Use `sol_advisor_test_executor` with Luna/xhigh for a difficult bounded test plan with
clear target state and acceptance criteria, and Luna/max only for exceptional
non-critical test complexity or evidence uncertainty. It executes a primary-authored
plan and never owns final high-risk or release sign-off.

This role executes a frozen ordered plan, manages only its authorized side effects,
produces the declared evidence, and owns its resume cursor. It does not invent an
independent attack angle or perform final adversarial verification; that belongs to
Local Code Verifier.

Initial dispatch:

~~~text
PLAN_ID: <stable identity for this exact test plan and material scope>
TEST_PLAN: <ordered test IDs, dependencies, steps, and expected results>
SCOPE: <exclusive code, interfaces, targets, environments, and exclusions>
AUTHORIZED_SIDE_EFFECTS: <allowed target-state changes; none unless explicit>
PASS_FAIL_CRITERIA: <per-test and whole-plan completion rules>
EVIDENCE_OUTPUT: <exclusive directory for logs, captures, and reports, or response-only>
STOP: <invalidated evidence, unsafe/unknown state, missing prerequisite, or expansion>
~~~

Repair-resume follow-up to the same native child:

~~~text
PLAN_ID: <the unchanged initial plan identity>
REPAIR_SUMMARY: <what the primary or repair agent changed>
REPAIR_EVIDENCE: <checks or locators establishing the repair is ready to retest>
INVALIDATED_PREREQUISITES: <completed tests that must be rerun, or none>
RESUME_POINT: <blocking test and remaining ordered tests>
STOP: <material plan/scope change, route change, unsafe state, or new blocker>
~~~

Required final fields: `STATUS`, `PLAN_RESULT`, `EVIDENCE`, `COVERAGE`,
`TARGET_STATE`.

Required when `STATUS: BLOCKED`: `NEXT_ACTION`, `BLOCKER`.

`NEXT_ACTION` must be exactly `REPAIR_RESUME`, `NEW_CHILD`, or `PRIMARY_DECISION`.
Use `REPAIR_RESUME` only when a repair can preserve `PLAN_ID`, model, effort, and
material scope. Use `NEW_CHILD` when a new full run, material plan/scope change, route
change, or unusable target state requires a fresh child. Use `PRIMARY_DECISION` for
any other primary-owned decision or action.

Required only when `NEXT_ACTION: REPAIR_RESUME`: `RESUME_POINT`, `REMAINING_TESTS`.

Optional when nonempty: `FINDINGS`, `OUTPUT_ARTIFACTS`.

Soft budget: 900-2200 characters. Source and configuration remain read-only; only
evidence under `EVIDENCE_OUTPUT` may be written. Non-blocking findings do not stop
independent tests. A repair-resume follow-up may reactivate this same child repeatedly
for the same plan; a new full run or material plan/scope change requires a new child.
