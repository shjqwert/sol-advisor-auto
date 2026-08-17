# Local Code Verifier

Use `sol_advisor_local_code_verifier` with Luna/medium for routine deterministic checks,
Luna/high for multiple boundaries or edge cases, Luna/xhigh for difficult bounded
uncertainty, and Luna/max only for exceptional non-critical uncertainty. Use Sol/xhigh
for security, authorization, concurrency, state, data, migration, public-API, or
release risk, and Sol/max only for irreversible or system-level sign-off.

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
