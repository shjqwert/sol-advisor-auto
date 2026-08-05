# Functional agent contracts

Use the smallest contract that makes the assigned question unambiguous. Every contract
must state the role, exact scope, the decision it informs, access boundary, and stop
condition. Add evidence or return fields only when they help that task.

## Shared spawn gate

Before spawn, run `../../scripts/install-agents.sh --check` and validate the intended
combination with `../../scripts/validate-agent-route.sh`. After spawn, confirm native
details; use `../../scripts/inspect-agent-runtime.sh` only when public details omit
model or effort. Reject a missing, mismatched, or unobservable route.

All children must preserve concurrent work, stay in assigned scope, avoid plugin,
Skill, and MCP configuration changes, and never spawn descendants. Use the smallest
positive inherited context that carries the complete contract, normally
`fork_turns: 1`.

## Discovery contract

Use `sol_advisor_repo_scout` with Luna/xHigh for ordinary discovery, or
`sol_advisor_precision_scout` with Luna/Max for exact call paths and boundaries.

~~~text
QUESTION: <one repository question>
SCOPE: <directories, files, symbols, or exclusions>
DECISION: <what the primary session will decide from the result>
RETURN: relevant paths/symbols and a short relevance note; include a call edge or
test observation only when it changes the decision.
STOP: remain read-only; do not implement or broaden scope.
~~~

## Context-analysis contract

Use `sol_advisor_context_analyst` with Terra/xHigh for long-context compression or
Terra/Max for cross-module constraints.

~~~text
QUESTION: <one long-context or cross-module question>
SOURCES: <bounded documents, logs, modules, or exclusions>
DECISION: <what conclusion can change the plan>
RETURN: decision-relevant facts with concrete source locations; label inference.
STOP: remain read-only; omit unrelated summary.
~~~

## Mechanical-edit contract

Use `sol_advisor_mechanical_editor` with Luna/Max only when the transformation is
fully determined and mechanically verifiable. Never run mechanical editors in
parallel on shared files or dependency chains.

~~~text
CHANGE: <exact deterministic transformation>
FILES: <exclusive file list>
PRESERVE: <interfaces and unrelated edits>
VERIFY: <exact command or deterministic inspection and expected result>
RETURN: changed files and actual verification result.
STOP: if judgment, architecture, ambiguity, or out-of-scope edits are required, make
no further changes and report the blocker.
~~~

The primary session must inspect the actual diff and rerun the minimum relevant check.

## Independent verification contracts

Use `sol_advisor_deepseek_adversarial_verifier` for the cross-model angle and
`sol_advisor_local_code_verifier` with Luna/Max for the local code/test angle. Add
Terra/Max only for a distinct cross-module angle. Each verifier receives a different
question and cannot read other conclusions.

~~~text
PROPOSED BEHAVIOR: <claim being attacked>
ATTACK ANGLE: <one independent failure class>
SCOPE: <files, interfaces, evidence, and exclusions>
RETURN: only reproducible actionable issues with trigger, impact, and supporting
location; otherwise “no blocking issue found” plus checked scope.
STOP: remain read-only; do not implement, perform general discovery, or inspect another
verifier's conclusion.
~~~

DeepSeek receives a complete contract in inherited context with `fork_turns: 1`; its
fixed TOML route is not overridden.

## Sol adjudication contract

Use `sol_advisor_final_adjudicator` only when evidence conflicts or critical risk needs
a final decision. Choose Sol effort from the risk rules in SKILL.md.

~~~text
DECISION: <the disputed ship/fix/rethink question>
EVIDENCE A: <compact finding and source>
EVIDENCE B: <compact conflicting finding and source>
CONSTRAINTS: <safety, compatibility, reversibility, and excluded scope>
RETURN: exactly one verdict—ship, fix-first, or rethink—then the minimum decisive
rationale and any required action.
STOP: remain read-only; do not implement.
~~~

If DeepSeek is unavailable, state that fact in this packet, use Luna/Max plus Terra/Max
independent verification, and force Sol/Max. The final report must disclose the loss
of cross-provider independence.
