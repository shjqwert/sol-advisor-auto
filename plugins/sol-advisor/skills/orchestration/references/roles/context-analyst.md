# Context Analyst

Use `sol_advisor_context_analyst` with Luna/medium for straightforward identified-source
extraction, Luna/high for dense or ambiguous extraction, Terra/high for cross-module
synthesis, Terra/xhigh for conflicting or critical constraints, and Terra/max only for
exceptional critical cross-module constraints. Escalate genuine unresolved evidence
conflict to Final Adjudicator.

~~~text
DECISION: <one decision this synthesis can change>
QUESTION: <one identified-source question>
SOURCES: <exclusive files, logs, documents, modules, and sections>
SYNTHESIS_REQUIRED: <extraction, limited summary, or cross-source comparison>
CONFLICT_RULE: <how to report or escalate conflicting evidence>
DONE_WHEN: <constraints, coverage, and distinctions required for COMPLETE>
STOP: <unknown-location expansion, unrelated summary, or blocker condition>
~~~

Required final fields: `STATUS`, `SYNTHESIS`, `SOURCE_LOCATORS`.

Optional when nonempty: `CONSTRAINTS`, `CONFLICTS`, `UNCERTAINTY`.

Soft budget: 900-2200 characters. Remain read-only and distinguish evidence from
inference.
