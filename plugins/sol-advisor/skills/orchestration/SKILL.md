---
name: orchestration
description: "Explicit Sol Advisor workflow for keeping complex implementation in the primary Codex session while dynamically routing bounded repository discovery, precision investigation, long-context analysis, deterministic mechanical edits, conditional adversarial verification, and final evidence adjudication to functional custom agents. Use when the user explicitly requests Sol Advisor orchestration, dynamic subagent routing, parallel independent validation, or cross-model DeepSeek verification."
---

# Sol Advisor Orchestration

Keep requirements, design, complex implementation, final verification, and integration
in the primary session. Use child agents only when they reduce context load or perform
a fully determined mechanical edit. Do not add agents merely to increase agreement.

Read [references/role-contracts.md](references/role-contracts.md) before the first
spawn in a session. Its contracts are adaptive: include only evidence and return fields
that matter to the assigned question.

## Preflight and route validation

Resolve scripts relative to this SKILL.md, never from the caller's working directory:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
installer="$skill_dir/../../scripts/install-agents.sh"
route_validator="$skill_dir/../../scripts/validate-agent-route.sh"
runtime_inspector="$skill_dir/../../scripts/inspect-agent-runtime.sh"
sh "$installer" --check
~~~

The native spawn tool must expose all seven routed agent types:

- `sol_advisor_repo_scout`
- `sol_advisor_precision_scout`
- `sol_advisor_mechanical_editor`
- `sol_advisor_context_analyst`
- `sol_advisor_deepseek_adversarial_verifier`
- `sol_advisor_local_code_verifier`
- `sol_advisor_final_adjudicator`

Before each spawn, validate the intended role, provider, model, and effort. After
spawn, use public native details first; if model or effort is omitted and the local
rollout is accessible, run the read-only runtime inspector with the native thread id.
Validate the observed combination again. Public and local evidence must agree.

~~~sh
sh "$route_validator" <role> <provider> <model> <effort>
sh "$runtime_inspector" <native-subagent-thread-id>
~~~

Stop the affected lane if its role or route is unavailable, inconsistent, or
unobservable. Never silently substitute a model, effort, or role.

## Allowed routes

| Purpose | Agent type | Spawn model and effort | Access |
|---|---|---|---|
| Ordinary repository search | `sol_advisor_repo_scout` | `gpt-5.6-luna` / `xhigh` | read-only |
| Precise call-path or boundary analysis | `sol_advisor_precision_scout` | `gpt-5.6-luna` / `max` | read-only |
| Deterministic mechanical edit | `sol_advisor_mechanical_editor` | `gpt-5.6-luna` / `max` | writable |
| Long-context compression | `sol_advisor_context_analyst` | `gpt-5.6-terra` / `xhigh` | read-only |
| Cross-module constraint analysis | `sol_advisor_context_analyst` | `gpt-5.6-terra` / `max` | read-only |
| Cross-model adversarial verification | `sol_advisor_deepseek_adversarial_verifier` | fixed DeepSeek V4 Flash / `xhigh` (DeepSeek Max) | read-only |
| Local code and test attack | `sol_advisor_local_code_verifier` | `gpt-5.6-luna` / `max` | read-only |
| Evidence adjudication | `sol_advisor_final_adjudicator` | `gpt-5.6-sol` / `medium`, `high`, `xhigh`, or `max` | read-only |

Luna permits only `xhigh|max`; Terra permits only `xhigh|max`; Sol permits only
`medium|high|xhigh|max`. Ultra is forbidden for every routed role. DeepSeek is fixed
by its TOML; Codex `xhigh` maps to DeepSeek Max reasoning.

The Luna, Terra, and Sol templates deliberately omit model and effort. Pass both in
the spawn request and validate them. The DeepSeek template pins provider, model,
effort, read-only access, empty Skill/MCP configuration, and disabled multi-agent use;
do not override those values.

## Decide whether to delegate

Use no child agent when the primary session already has enough evidence or when
delegation would duplicate work.

- Send ordinary location work to Luna/xHigh.
- Send exact call-path, boundary, or local-behavior investigation to Luna/Max.
- Send long-context compression to Terra/xHigh and independent cross-module analysis
  to Terra/Max. Terra never implements.
- Send only exact, deterministic, mechanically verifiable edits to Luna/Max. Shared
  files, dependency chains, architectural choices, and ambiguous fixes stay primary.
- Use DeepSeek only for cross-model adversarial verification, never general search or
  implementation.
- Use Sol only to adjudicate material conflicts; ordinary completion does not require
  a Sol review.

Use the smallest positive inherited context sufficient to deliver the complete task,
normally `fork_turns: 1`. This is required for DeepSeek task delivery; do not use a
message-only or zero-context DeepSeek spawn. Include exact scope and the one question
whose answer can change the primary decision.

If a particular Skill is required, name it explicitly in the child contract. A child
does not automatically execute a Skill already used by the primary session. Role
configuration may otherwise inherit available Skill and MCP definitions, but no child
may install, enable, disable, or modify plugins, Skills, or MCP configuration.

## Parallelism and independence

- Ordinary task: at most one child agent.
- Complex task: at most two, and only for independent questions.
- Critical risk: DeepSeek/Max and Luna/Max validate in parallel by default.
- Add Terra/Max as a third validator only for a distinct cross-module question.

Parallel children must be read-only, receive non-overlapping attack angles, and never
read each other's conclusions. Keep mechanical writes, shared files, and dependency
chains serial. No role may spawn descendants.

## Verification and adjudication

After primary implementation and verification:

1. Finish immediately for low-risk work with no material uncertainty.
2. For substantive uncertainty, run DeepSeek adversarial verification.
3. For critical risk, run the independent DeepSeek and Luna validators in parallel;
   optionally add Terra only for a separate cross-module angle.
4. Merge duplicate findings into one item. Reproduce only findings that change the
   implementation, block delivery, or require adjudication.
5. Fix clear defects in the primary session and rerun primary verification.
6. Send genuine evidence conflicts to Sol at dynamic effort:
   - medium: bounded, evidence-rich, low-impact dispute;
   - high: ordinary semantic conflict or verification gap;
   - xhigh: security, concurrency, data, public API, or cross-module risk;
   - max: architecture rethink, irreversible change, severe verifier conflict, or
     DeepSeek-degraded fallback.

The Sol adjudicator returns `ship`, `fix-first`, or `rethink`. It never implements.

## DeepSeek unavailable

Warn explicitly. Run Luna/Max and Terra/Max as independent read-only validators, then
force Sol/Max adjudication. State in the final report that cross-provider independence
was unavailable. Never present the fallback as equivalent to DeepSeek verification.

## Accepting child results

Child output is a claim, not proof. Keep it brief and task-shaped:

- discovery: paths, symbols, and one-line relevance;
- adversarial verification: reproducible trigger, impact, and supporting location;
- mechanical edit: changed files and actual verification;
- no finding: checked scope and “no blocking issue found”.

The primary session opens only evidence that can change the plan or delivery decision,
checks the actual diff after a mechanical edit, and reruns the minimum relevant tests.
Do not repeat an entire child investigation merely for ceremony.
