# Final Adjudicator

Use `sol_advisor_final_adjudicator` with Sol/high for routine independent review,
Sol/xhigh for a complex cross-module decision, and Sol/max only for rare unresolved
high-consequence adjudication. Use Astra/high for key architecture, complex
long-running task decisions, or contested adjudication, Astra/xhigh when those span
difficult boundaries, and Astra/max only when a rare critical decision cannot
otherwise converge. The primary passes the selected model and effort explicitly. It
may inspect supplied code or tests as evidence for the decision, but it does not verify
concrete code, tests, implementation correctness, or release sign-off; route those
claims to Local Code Verifier. The review object must be a decision-level proposed
solution or supplied conflict.

For a proposed solution:

~~~text
MODE: SOLUTION_REVIEW
DECISION: <one decision this review can inform>
USER_CONFIRMED_BASELINE: <goals, constraints, choices, and accepted risks the reviewer must not override>
PROPOSED_SOLUTION: <decision-level plan, recommendation, or exact artifact locators>
GOALS_AND_CONSTRAINTS: <success criteria and material boundaries>
ATTACK_ANGLES: <goal fit, constraints, tradeoffs, counterexamples, assumptions, and omissions to challenge>
EVIDENCE_LOCATORS: <decisive files, documents, tests, logs, or sections>
KNOWN_UNKNOWNS: <missing user or environment state that must remain unknown>
DONE_WHEN: <coverage required for COMPLETE>
STOP: <scope expansion, missing review object, open-ended investigation, or a concrete implementation-verification or release-sign-off question>
~~~

For supplied conflicts:

~~~text
MODE: CONFLICT_REVIEW
DECISION: <one decision this review can inform>
USER_CONFIRMED_BASELINE: <confirmed choices and accepted risks the reviewer must not override>
CONFLICTING_CLAIMS: <compact claims that cannot all be true>
EVIDENCE_LOCATORS: <decisive locators for every supplied claim>
CONSTRAINTS: <safety, compatibility, reversibility, and release constraints>
KNOWN_UNKNOWNS: <missing state that must remain unknown>
DONE_WHEN: <conflict branches and constraints required for COMPLETE>
STOP: <missing decisive evidence, new investigation, or implementation condition>
~~~

Required final fields: `STATUS`, `VERDICT`, `FINDINGS`, `DECISIVE_EVIDENCE`.

Optional when nonempty: `UNSUPPORTED_ASSUMPTIONS`, `MISSING_USER_STATE`,
`USER_DECISIONS_REQUIRED`, `RESIDUAL_RISKS`, `RECOMMENDATION`.

`VERDICT` must be exactly `NO_MATERIAL_GAP_FOUND`, `MATERIAL_CONCERNS`, or
`INSUFFICIENT_EVIDENCE`. The verdict and recommendation are advisory: the primary
must verify decisive evidence and present decision-changing findings to the user
before any repair, acceptance, or risk decision. Remain read-only. Soft budget:
900-2200 characters.
