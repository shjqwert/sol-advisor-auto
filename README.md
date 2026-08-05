# Sol Advisor

**Automatically keep complex implementation in the primary Codex session while
delegating bounded search, research, deterministic edits, and conditional validation.**

Sol Advisor is an implicitly matched Codex orchestration workflow for non-trivial
repository work. It uses functional custom-agent roles and chooses Luna, Terra, or Sol
reasoning strength from task shape. DeepSeek V4 Flash is reserved for cross-model
adversarial verification. Trivial one-step work stays outside the workflow.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

| Functional role | Model route | Access | Purpose |
|---|---|---|---|
| `sol_advisor_repo_scout` | Luna/xHigh | read-only | Ordinary files, symbols, and tests |
| `sol_advisor_precision_scout` | Luna/Max | read-only | Exact call paths, boundaries, and local behavior |
| `sol_advisor_external_researcher` | Luna/xHigh or Max | read-only | Current external facts with source-quality checks |
| `sol_advisor_mechanical_editor` | Luna/Max | workspace-write | Fully determined, mechanically verifiable edits |
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
- Python 3.11+, a POSIX shell, `jq`, and common Unix tools (`cmp`, `mktemp`,
  `sha256sum`). On Windows, use WSL for the shell scripts.

~~~sh
codex plugin marketplace add DannyMac180/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
~~~

Plugin installation does not write user-owned custom-agent files. Install the eight
routed templates separately:

~~~sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
~~~

Windows PowerShell example (use the Windows Codex agent directory explicitly):

~~~powershell
$pluginDir = (codex plugin list --json | ConvertFrom-Json).installed |
  Where-Object pluginId -eq 'sol-advisor@sol-advisor' |
  Select-Object -ExpandProperty source |
  Select-Object -ExpandProperty path
$pluginDirWsl = wsl wslpath -a -u ($pluginDir -replace '\\','/')
$agentDirWsl = wsl wslpath -a -u (("$env:USERPROFILE\.codex\agents") -replace '\\','/')
wsl sh "$pluginDirWsl/scripts/install-agents.sh" --target-dir $agentDirWsl
wsl sh "$pluginDirWsl/scripts/install-agents.sh" --target-dir $agentDirWsl --check
~~~

The installer adds only missing routed templates, never edits `config.toml`, and
refuses to overwrite a differing file.

Start a new Codex task after installation so native roles and the bundled Skill are
rediscovered. If the Skill still does not appear, restart Codex before testing; an
already-running Desktop/app-server process can retain its earlier capability catalog.
The Skill can then activate automatically when a non-trivial repository task matches
its scoped description. Explicit invocation remains available:

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
- Total child budgets are 1 ordinary, 3 complex, and 5 critical; at most two fix rounds
  are allowed.
- A child is never launched unless the current runtime exposes its exact role, model,
  provider, spawn envelope, and a parent sandbox equal to the requested lane. In
  particular, read-only roles are not spawned from a `workspace-write` or
  `danger-full-access` parent turn.

Low-risk work does not require a child review. Material uncertainty triggers DeepSeek
adversarial verification. Critical risk uses independent parallel validation and Sol
adjudication only when findings conflict or require a final risk decision.

If DeepSeek is unavailable, the workflow warns explicitly, substitutes independent
Luna/Max and Terra/Max read-only validation, forces Sol/Max adjudication, and reports
that cross-provider independence was unavailable.

## Route and runtime evidence

Luna, Terra, and Sol role files do not pin model or effort. The Skill passes the
allowed combination at spawn time and validates it before and after spawn. Every batch
must first pass the executable dispatch-plan validator:

~~~sh
python3 "$plugin_dir/scripts/validate-dispatch-plan.py" \
  /path/to/temporary-plan.json --state-file /path/to/temporary-state.json
sh "$plugin_dir/scripts/validate-agent-route.sh" \
  sol_advisor_context_analyst openai gpt-5.6-terra max read-only disabled
~~~

The state file is mandatory for a run. It prevents accidental batch-counter resets,
makes DeepSeek unavailability sticky, records consumed child budget, and blocks a new
batch until every pending result has passed the result validator. It is a local runtime
guard, not a cryptographic defense against a process that can rewrite its own state.

Native spawn/details metadata is the primary evidence. If it omits model or effort
and the local rollout is accessible, inspect only the exact native child thread:

~~~sh
thread_id="<native-subagent-thread-id>"
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$thread_id"
~~~

The inspector emits only allowlisted routing and sandbox fields; it refuses invalid,
missing, duplicate, or inconsistent metadata. Route validation includes observed
sandbox and permission profile. A mismatched or unobservable route is not accepted and
is never silently replaced.

DeepSeek is the only fixed route. Its template pins the provider, V4 Flash model,
Codex xHigh reasoning (DeepSeek Max), read-only sandbox, empty Skill/MCP configuration,
and no descendant agents. Every role receives a self-contained native `message` and a
unique response token. Desktop `multi_agent_v1` uses `fork_context:false`; native CLI
uses a unique `task_name` and `fork_turns:"none"`. The dispatcher rejects any envelope
not exposed by the live surface and refuses unavailable Luna/Terra/Sol routes instead
of substituting another model.

## Child results

Output uses a small JSON envelope (`response_token`, `status`, `summary`, `scope`) plus
only the task-specific evidence nucleus:

- discovery returns paths, symbols, and short relevance;
- external research returns direct links, source class, dates, applicability, and
  fact/inference labels;
- adversarial verification returns a reproducible trigger, impact, and location;
- mechanical editing returns changed files and actual verification;
- no finding returns checked scope and “no blocking issue found”.

The exact returned text must pass `validate-agent-result.py` with the same run state.
That validates delivery, actual output size, and evidence shape; it does not establish
truth. The primary still verifies every decisive locator.

The primary session selectively reopens evidence that can change the implementation or
delivery decision, always inspects mechanical diffs, and reruns minimum relevant tests.
Sol Advisor tracks main-thread context and total model tokens separately: subagents can
reduce main-thread context pollution while increasing total tokens.

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

The verifier checks manifest and TOML syntax, dynamic route allowlists, risk/phase
classification, stateful budgets and degradation, result nuclei, installer path and
conflict safety, role access and reduced shell/web surfaces, both current spawn
envelopes, safe runtime extraction, LF shell syntax, and route permission metadata. It
does not invoke a model or API.

Actual native-agent smoke tests can incur model/API cost and should be run only after
explicit authorization. Acceptance must inspect observed role, provider, model,
effort, sandbox, permission profile, and the requested response—not routing metadata
alone.

## License

MIT
