# Sol Advisor

**Automatically keep complex implementation in the primary Codex session while
delegating bounded search, research, deterministic edits, and conditional validation.**

Sol Advisor is an implicitly matched Codex orchestration workflow for non-trivial
repository work. It uses functional custom-agent roles and chooses Luna, Terra, or Sol
reasoning strength from task shape. Trivial one-step work stays outside the workflow.

| Functional role | Model route | Behavioral boundary | Purpose |
|---|---|---|---|
| `sol_advisor_investigator` | Luna/xHigh or Max | no edits | Difficulty-aware repository, precision, and external investigation |
| `sol_advisor_mechanical_editor` | Luna/xHigh or Max; Terra only for long context | bounded serial edits | Fully determined, mechanically verifiable edits |
| `sol_advisor_context_analyst` | Terra/xHigh or Max | no edits | Long-context compression or critical cross-module verification |
| `sol_advisor_local_code_verifier` | Luna/Max | no edits | Local code, boundary, and test-gap attack |
| `sol_advisor_final_adjudicator` | Sol/Medium, xHigh, or Max | no edits | Resolve material evidence conflicts |

Luna and Terra permit only xHigh or Max. Sol permits Medium, xHigh, or Max.
Ultra is forbidden. Every role disables descendant agents.

## Install

Requirements:

- A current Codex Desktop app with plugins, sidebar-visible subagents, and custom agents.
- Access to the selected GPT-5.6 routes.
- Python 3.11+, a POSIX shell, `jq`, and common Unix tools (`cmp`, `mktemp`,
  `sha256sum`). The shipped Python runner prefers `python`/`py -3` on Windows and
  `python3` on POSIX; set `SOL_ADVISOR_PYTHON` only when an explicit interpreter is
  required. On Windows, use WSL or an MSYS-compatible shell for shell scripts.
- `uvx` for the bundled MarkItDown MCP. CodeGraph and Serena remain optional but are
  strongly recommended for repository work.

~~~sh
codex plugin marketplace add shjqwert/sol-advisor-auto --ref main
codex plugin add sol-advisor@sol-advisor
~~~

Plugin installation does not write user-owned custom-agent files. Install the five
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

The plugin exposes the balanced search set selected for the pilot:

- inherited CodeGraph and Serena for repository relationships and symbols;
- Context7 for version-aware library documentation;
- Exa for read-only current web search and clean page retrieval;
- MarkItDown for local PDF and Office-document conversion.

Context7 and Exa use their official hosted MCP endpoints and work at anonymous rate
limits; their API keys remain optional for higher quotas. MarkItDown runs locally
through `uvx markitdown-mcp`, so the first use may download its isolated dependencies.
Child results do not list which MCP, Skill, or plugin was used; capability and fallback
diagnostics stay outside the result envelope.

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

Investigation and mechanical-edit routes declare `difficulty` as `standard` or
`deep`. Standard work uses Luna/xHigh and deep work uses Luna/Max. Terra editing is a
capability exception for explicit `long_context` work, not a general difficulty
upgrade; multi-module long-context edits use Terra/Max.

- Ordinary work uses at most one child.
- Complex work uses at most two children and only for independent questions.
- Critical risk runs Luna/Max and Terra/Max non-editing validators in parallel with
  distinct local-code and cross-module attack angles.
- Validators cannot read each other's conclusions; shared files, dependency chains,
  and all mechanical writes stay serial.
- Total child budgets are 1 ordinary, 3 complex, and 5 critical; at most two fix rounds
  are allowed.
- A child is never launched unless the current runtime exposes its exact role, model,
  provider, and spawn envelope. Every child inherits the active parent task sandbox and
  permission profile. Sol Advisor neither restricts nor compares that inherited
  permission; role instructions remain behavioral boundaries rather than sandbox gates.

Low-risk work does not require a child review. Material uncertainty triggers one
Luna/Max local verification. Critical risk uses independent parallel validation and Sol
adjudication only when findings conflict or require a final risk decision.

## Repository search policy

Custom-agent files omit `mcp_servers` and `skills.config`, which lets Codex inherit the
parent task's live capabilities. Search routing is intent-driven rather than tied to a
specific repository:

- symbols and references: Serena, then CodeGraph, then exact text search;
- call paths, impact, and architecture: CodeGraph, then Serena, then exact text search;
- configuration and logs: exact text search and targeted reads;
- library/API documentation: Context7, then official documentation;
- current web facts: built-in web, then Exa;
- local PDF/Office files: MarkItDown, then the inherited document/PDF Skills.

Missing indexes do not disable CodeGraph or Serena. The primary session may prepare
them for the exact Git, SVN, or plain workspace root before a broad local route:

~~~sh
sh "$plugin_dir/scripts/run-python.sh" \
  "$plugin_dir/scripts/prepare-repo-search.py" /exact/repository/root \
  --indexing create-if-missing --apply
~~~

The preflight reports its plan as JSON, never stages or adds generated metadata, and
fails if index preparation introduces a working-file change. Exact text search excludes
`.sol-advisor` plus index/cache directories by default, while `.agents`, `.agent`,
`.codex`, generated sources, and build output remain task-dependent instead of being globally excluded.
During the pilot there are no per-child command, elapsed-time, or token ceilings.

## Route and runtime evidence

Each role file pins its base model while reasoning effort remains route-selected.
Investigation, mechanical editing, and local verification use Luna; context analysis
uses Terra; final adjudication uses Sol. The Skill omits the spawn model override for
the pinned base and uses an explicit override only for the gated Terra mechanical-edit
exception. Every batch
must first pass the executable dispatch-plan validator:

~~~sh
sh "$plugin_dir/scripts/run-python.sh" "$plugin_dir/scripts/validate-dispatch-plan.py" \
  <run-directory>/plans/<batch-id>.json \
  --repository /exact/repository/root \
  --state-file <run-directory>/state.json
sh "$plugin_dir/scripts/validate-agent-route.sh" \
  sol_advisor_context_analyst openai gpt-5.6-terra max
~~~

For Git, the run lives under the exact administrative directory resolved by
`git rev-parse --absolute-git-dir`, normally `.git/sol-advisor/runs/<run-id>/`. SVN and
plain directories use `<workspace-root>/.sol-advisor/runs/<run-id>/` and never write
inside `.svn`. The state file prevents accidental batch-counter resets,
records consumed child budget, and blocks a new
batch until every pending result has passed the result validator. It is a local runtime
guard, not a cryptographic defense against a process that can rewrite its own state.

Native spawn/details metadata is the primary evidence. If it omits model or effort
and the local rollout is accessible, inspect only the exact native child thread:

~~~sh
thread_id="<native-subagent-thread-id>"
sh "$plugin_dir/scripts/inspect-agent-runtime.sh" "$thread_id"
~~~

The inspector emits only allowlisted routing fields plus sandbox and permission values
when they are observable. Route acceptance compares role, provider, model, and effort;
sandbox and permission values are diagnostic and are not restricted or compared.

Every role receives a self-contained Desktop collaboration v2 `message`, a unique
sidebar `task_name`, `fork_turns:"none"`, and a unique response token. Native CLI
spawning is not an accepted operational surface. The dispatcher distinguishes catalog
models, live model overrides, and installed base-model pins, and refuses unavailable
routes instead of substituting another model.

## Child results

Each sidebar result shows only concise Markdown: conclusion, status, scope, and
task-specific details. Before returning, the child writes a small JSON sidecar
(`response_token`, `status`, `summary`, `scope`) plus the task-specific evidence nucleus
to its validated path under the run directory:

~~~text
## 结论 / Result

Readable conclusion.

- 状态 / Status: `completed`
- 范围 / Scope: checked files or sources
- 详情 / Details: decisive evidence or action
~~~

The machine sidecar contains only the required evidence nucleus:

- discovery returns paths, symbols, and short relevance;
- external research returns direct links, source class, dates, applicability, and
  fact/inference labels;
- verification returns a reproducible trigger, impact, and location;
- mechanical editing returns changed files and actual verification;
- no finding returns checked scope and “no blocking issue found”.

The exact returned Markdown, machine sidecar, and exact-child runtime metadata must pass
`validate-agent-result.py --machine-result ... --runtime-metadata ...` with the same run
state. That rejects JSON or legacy envelopes in the visible response, checks readable
Markdown against the sidecar summary and status, binds role/provider/model/effort, and
validates artifact paths, delivery, payload size, and evidence shape. It does not
establish truth. The primary still confirms or rejects every decisive locator.

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
classification, stateful budgets, result nuclei, installer path and
conflict safety, inherited-permission configuration and reduced shell/web surfaces,
the current spawn envelope, safe runtime extraction, LF shell syntax, and route identity
metadata. It
does not invoke a model or API.

Actual native-agent smoke tests can incur model/API cost and should be run only after
explicit authorization. Acceptance must inspect observed role, provider, model,
effort, and the requested response—not routing metadata alone. Sandbox and permission
profile may be recorded for diagnostics but do not gate acceptance.

## License

MIT
