# Sol Advisor

**Keep complex implementation in the primary Codex session. Delegate bounded search,
long-context analysis, deterministic edits, and conditional independent verification.**

Sol Advisor is an explicitly invoked Codex orchestration workflow. It uses functional
custom-agent roles and chooses Luna, Terra, or Sol reasoning strength from task shape.
DeepSeek V4 Flash is reserved for cross-model adversarial verification.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

| Functional role | Model route | Access | Purpose |
|---|---|---|---|
| `sol_advisor_repo_scout` | Luna/xHigh | read-only | Ordinary files, symbols, and tests |
| `sol_advisor_precision_scout` | Luna/Max | read-only | Exact call paths, boundaries, and local behavior |
| `sol_advisor_mechanical_editor` | Luna/Max | writable | Fully determined, mechanically verifiable edits |
| `sol_advisor_context_analyst` | Terra/xHigh or Max | read-only | Long-context compression or cross-module constraints |
| `sol_advisor_deepseek_adversarial_verifier` | DeepSeek V4 Flash/Max | read-only | Cross-model adversarial verification only |
| `sol_advisor_local_code_verifier` | Luna/Max | read-only | Local code, boundary, and test-gap attack |
| `sol_advisor_final_adjudicator` | Sol/Medium, High, xHigh, or Max | read-only | Resolve material evidence conflicts |

Luna and Terra permit only xHigh or Max. Sol permits Medium, High, xHigh, or Max.
Ultra is forbidden. Every role disables descendant agents.

## Install

Requirements:

- A current Codex CLI or Desktop app with plugins, native subagents, and custom agents.
- Access to the selected GPT-5.6 routes.
- `DEEPSEEK_API_KEY` in the Codex process environment when DeepSeek verification is
  used. Restart Codex after changing environment variables on Windows.
- `jq` for the helper commands below.

~~~sh
codex plugin marketplace add DannyMac180/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
~~~

Plugin installation does not write user-owned custom-agent files. Install the seven
routed templates separately:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

The installer adds only missing routed templates, never edits `config.toml`, and
refuses to overwrite a differing file.

Start a new Codex task after installation so native roles are rediscovered. Invoke the
Skill explicitly; it does not intercept ordinary requests:

~~~text
Use $sol-advisor:orchestration for this task. Keep complex implementation in the main
session and delegate only bounded investigation, mechanical work, or conditional
verification.
~~~

## Routing policy

The primary session owns requirements, design, complex implementation, final tests,
and integration. It delegates only when the task is bounded enough to save context or
is a deterministic edit.

- Ordinary work uses at most one child.
- Complex work uses at most two children and only for independent questions.
- Critical risk runs DeepSeek and Luna read-only validators in parallel.
- Terra is a third validator only for a separate cross-module attack angle.
- Validators cannot read each other's conclusions; shared files, dependency chains,
  and all mechanical writes stay serial.

Low-risk work does not require a child review. Material uncertainty triggers DeepSeek
adversarial verification. Critical risk uses independent parallel validation and Sol
adjudication only when findings conflict or require a final risk decision.

If DeepSeek is unavailable, the workflow warns explicitly, substitutes independent
Luna/Max and Terra/Max read-only validation, forces Sol/Max adjudication, and reports
that cross-provider independence was unavailable.

## Route and runtime evidence

Luna, Terra, and Sol role files do not pin model or effort. The Skill passes the
allowed combination at spawn time and validates it before and after spawn:

~~~sh
sh "$plugin_dir/scripts/validate-agent-route.sh" \
  sol_advisor_context_analyst openai gpt-5.6-terra max
~~~

Native spawn/details metadata is the primary evidence. If it omits model or effort
and the local rollout is accessible, inspect only the exact native child thread:

~~~sh
thread_id="<native-subagent-thread-id>"
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$thread_id"
~~~

The inspector emits only allowlisted routing and sandbox fields; it refuses invalid,
missing, duplicate, or inconsistent metadata. A mismatched or unobservable route is
not accepted and is never silently replaced.

DeepSeek is the only fixed route. Its template pins the provider, V4 Flash model,
Codex xHigh reasoning (DeepSeek Max), read-only sandbox, empty Skill/MCP configuration,
and no descendant agents. It receives a complete narrow contract through the smallest
positive inherited context, normally one turn.

## Child results

Output follows the task instead of a universal report template:

- discovery returns paths, symbols, and short relevance;
- adversarial verification returns a reproducible trigger, impact, and location;
- mechanical editing returns changed files and actual verification;
- no finding returns checked scope and “no blocking issue found”.

The primary session selectively reopens evidence that can change the implementation or
delivery decision, always inspects mechanical diffs, and reruns minimum relevant tests.

## Local development

Install a checkout as a local marketplace:

~~~sh
cd /absolute/path/to/sol-advisor
codex plugin marketplace add /absolute/path/to/sol-advisor
codex plugin add sol-advisor@sol-advisor
~~~

Run the no-cost repository checks in a disposable agent target:

~~~sh
cd /absolute/path/to/sol-advisor
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
~~~

The verifier checks manifest and TOML syntax, dynamic route allowlists and illegal
combinations, installer idempotence and conflict safety, role access boundaries,
concurrency and DeepSeek-degradation contracts, safe runtime metadata extraction, and
shell syntax. It does not invoke a model or API.

Actual native-agent smoke tests can incur model/API cost and should be run only after
explicit authorization. Acceptance must inspect observed role, provider, model,
effort, sandbox, permission profile, and the requested response—not routing metadata
alone.

## License

MIT
