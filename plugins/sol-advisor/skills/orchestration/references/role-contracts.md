# Functional agent contract index

Read this common index once before the first child. Then read exactly one selected
role contract; do not load the other role files. Send the selected contract's required
fields in order, followed by task-specific project constraints. Do not send
conversation history, raw source contents, or primary reasoning when locators suffice.

## Select one role contract

- `sol_advisor_investigator`: [Investigator](roles/investigator.md)
- `sol_advisor_context_analyst`: [Context Analyst](roles/context-analyst.md)
- `sol_advisor_mechanical_editor`: [Mechanical Editor](roles/mechanical-editor.md)
- `sol_advisor_local_code_verifier`: [Local Code Verifier](roles/local-code-verifier.md)
- `sol_advisor_final_adjudicator`: [Final Adjudicator](roles/final-adjudicator.md)
- `sol_advisor_spark_worker`: [Spark Worker](roles/spark-worker.md)

## Common lifecycle

Every child:

- follows applicable `AGENTS.md` files and inherited parent instructions;
- stays inside the supplied scope and stop conditions;
- does not create or manage other agents;
- returns one ordinary final response and ends immediately;
- sends no progress, status, or result through parent-interaction messaging;
- uses `STATUS: COMPLETE | INCOMPLETE | BLOCKED`; and
- omits empty optional fields, raw logs, tool narration, progress, and repetition.

Do not require a response token, result path, sidecar, plugin-owned state, universal
return mode, task-understanding paragraph, or fixed nine-heading result. Completeness
overrides a selected role's soft output budget.

## One corrective follow-up

Use one follow-up only when the result is directionally correct and one bounded
omission prevents completion. Keep the same child, model, and effort.

~~~text
CORRECTION: <one exact misunderstanding or omission>
MISSING_EVIDENCE: <specific locator, source, check, or comparison>
KEEP: <correct prior work that must not be repeated>
STOP: <condition requiring primary takeover or a new stronger child>
~~~

Do not follow up for formatting alone, a wrong role, an unsafe route, or a task that
must be decomposed again. After one unusable correction, the primary takes over.
