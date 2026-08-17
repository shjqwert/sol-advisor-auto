# Investigator

Use `sol_advisor_investigator` with Luna/medium for straightforward bounded discovery,
Luna/high for cross-module search or official-source reconciliation, Luna/xhigh for
deep or incomplete evidence, and Luna/max only for high-stakes bounded evidence.

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
