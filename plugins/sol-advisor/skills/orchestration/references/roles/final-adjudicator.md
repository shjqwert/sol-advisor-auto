# Final Adjudicator

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
