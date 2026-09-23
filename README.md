# Sol Advisor

Version `3.0.0` is a lightweight native-agent collaboration plugin: three
model-independent role templates, explicit GPT-6 model and effort selection at spawn,
native teammate messaging, and ordinary final responses. Keep small tasks local;
delegate bounded work when a concrete task pattern fits and the result still meets the
required quality within an acceptable total cost.

## Roles and models

| Native agent type | Responsibility |
|---|---|
| `sol_advisor_scout` | Read-only discovery, focused research and evidence synthesis |
| `sol_advisor_worker` | Scoped implementation, local design, debugging and authorized checks |
| `sol_advisor_reviewer` | Independent examination of artifacts, claims and counterexamples; no fixes |

Scout investigates bounded code or source questions, including unknown file locations.
Worker owns scoped implementation, local design, debugging and authorized checks.
Reviewer independently examines implementation, design or conflicting evidence without
implementing fixes. Review is optional, not a stage added to every edit.

The current primary session remains coordinator and final owner. All three roles may
use `gpt-6-luna`, `gpt-6-sol` or `gpt-6-astra`. The OpenAI templates set the provider
but do not pin a model or reasoning effort; pass both explicitly in the native spawn
call. Name instances `<task>__<model_id>`, for example `trace_boot__gpt_6_luna`.

| Task | Starting choice | Harder work |
|---|---|---|
| Discovery and evidence organization | Luna high | Luna xhigh for difficult tracing; Sol for complex synthesis |
| Implementation and local debugging | Sol medium | Sol high for multi-step dependencies and edge cases |
| Independent review | Sol high | Sol xhigh for conflicting constraints or difficult counterexamples |
| Particularly difficult synthesis | Compare high-effort Sol with Astra | Astra starts at low; adjust upward for actual difficulty |

Luna supports high/xhigh/max in this policy. Sol and Astra support
low/medium/high/xhigh/max. Version 3 excludes none and ultra. Use max only for a
concrete hard reasoning obstacle, not merely because a role or result is important.
These are starting points rather than model capability guarantees or a forced
low-to-high trial ladder.

Choose effort from the reasoning chain length, cross-dependencies, conflicting
evidence and edge cases. Raise it when a conclusion feeds several later decisions and
an error would be hard to detect promptly. Foundational public interfaces or state
meanings can justify both higher effort and stronger independent verification.

## Native collaboration

Give a short assignment with goal, deliverable, owned scope, completion condition and
essential context or restrictions. Prefer fresh context for narrow tasks and inherit
only needed history where the host supports it. Respect host model, effort and fork
override rules.

Call `collaboration.send_message` directly when the host exposes it; it is not inside
`functions.exec` or its `ALL_TOOLS`. Otherwise children return evidence in ordinary
finals and the primary relays it with source attribution in a follow-up. Codex app
thread messaging is not a substitute for native agent messaging. A message does not
grant authority, transfer ownership, or wake an ended agent; the primary must arrange
the ended agent's follow-up. Children remain leaves and do not recursively spawn or
manage other agents.

Use one writer per conflicting file or resource, preserve user changes, and avoid
duplicate investigation. Shared test output and hardware also need exclusive ownership.
The primary continues disjoint work, handles scope changes and confirms execution has
stopped before takeover. Continue a useful child while it makes progress; no fixed
correction count or plugin-level agent count applies. Host concurrency and allowance
limits still apply.

Follow-ups keep the same child model and effort. Version 3 does not support switching
either inside a running child and makes no prompt-cache promise. If another
configuration is needed, end the old ownership before creating the new assignment, or
have the primary take over after inspecting partial work and transferring useful
evidence.

Children return ordinary results, evidence and unfinished work. No STATUS/VERDICT
enums, result sidecars or runtime scripts gate intake. The primary inspects actual
changes and decisive evidence, reuses valid checks and performs necessary integration.
Review covers the content actually inspected; changed inputs invalidate related
evidence. Unrun checks must remain explicitly unverified.

All roles inherit the task's applicable rules and capabilities. Model profiles do not
disable messaging or override permissions. Read-only and leaf responsibilities are
behavioral instructions, not a claim of tool-level isolation. Builds, devices, merges
and releases remain subject to the user's active authorization and project rules.

The optional Context7 MCP companion remains available for documentation. Missing tools
or profiles do not justify installation or reconfiguration: continue in the primary
or relay evidence when direct messaging is unavailable.

## Global default and project opt-out

### 自动分工判据

出现以下任一清晰、有界的模式时，可以考虑原生分工：把大量检索、日志或中间阅读与
主上下文隔离；应用专门指令、工具或执行边界；独立核对重要结论或竞争假设；分配可分离
模块、源码范围或调查维度；把清晰、重复的工作交给更低成本模型。简单任务通常由主会话
完成，速度本身不构成默认触发条件，也不要求 Scout → Worker → Reviewer 固定流水线。

质量要求与包含启动、上下文、通信、复核、整合和返工在内的总成本共同约束选择。
不要求数值评分、成功概率、派发报告或预检脚本，也不能在执行前声称已证明质量或耗时
收益。频繁交互、不可分割的共享上下文或高额交接成本通常更适合主会话。只有相互独立且
有用的工作才增加代理；数量由任务收益和宿主限制决定，插件本身不设数量上限。

Installing and enabling Sol Advisor makes its implicit-capable orchestration Skill
eligible in repositories, non-Git directories, empty folders, and from-scratch
workspaces. Eligibility permits automatic consideration but does not require a route
record or child. A workspace does not need a project `.agent` directory, authorization
file, or local `AGENTS.md`.

To disable implicit Sol Advisor delegation for one workspace, create a schema-v1
`.agent/authorizations.json` at its root. In a plain non-repository directory, the
current working directory is the workspace root:

```json
{
  "schemaVersion": 1,
  "authorizations": {
    "solAdvisor": {
      "implicitDelegation": false
    }
  }
}
```

An applicable `AGENTS.md` instruction can also explicitly disable Sol Advisor or all
delegation. Codex `agents.enabled = false` disables multi-agent tools independently.
Legacy `implicitDelegation: true` remains valid but is unnecessary; a missing file or
key leaves the global default enabled. An existing invalid or unreadable override
fails safe to primary-only execution until corrected.

An explicit current-task request to use Sol Advisor or `$orchestration` bypasses a
project opt-out. An explicit current-task instruction not to delegate always wins.

Sol Advisor never writes user- or project-level `AGENTS.md` files or `.agent` context,
authorization, plan, and handoff files. 按需建立或更新项目指导可使用独立的
`project-setup` Skill；它不管理委派授权，不是 Sol Advisor 的依赖。
上面的已有委派禁用设置仍然有效，不因停用上下文插件而失效。

The primary passes relevant context and current restrictions to fresh children,
checks their ordinary results. 重要决定及理由由主窗口在已授权范围内记录到已有
设计文档、ADR 或 Issue，复用原记录，不建立第二套计划、交接或消息状态库。
子代理完成不自动触发持久化；原生通信或主窗口转发仅用于当前任务。
用户改变决定时只修订受影响的记录，测试通过不等于新目标获批。


## Installation

Install from the standalone marketplace:

```sh
codex plugin marketplace add shjqwert/sol-advisor-auto --ref main
codex plugin add sol-advisor@sol-advisor
```

Plugin installation does not write user- or project-owned instructions or custom-agent
files. Install the three model-independent native templates separately:

```sh
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')"
test -d "$plugin_dir"
sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
```

For an existing exact recognized Sol Advisor installation, use the managed upgrade:

```sh
sh "$plugin_dir/scripts/install-agents.sh" --upgrade-managed
sh "$plugin_dir/scripts/install-agents.sh" --check
```

Managed upgrade recognizes the exact known 2.0.1 four-profile installation, along with
other supported historical template hashes, in LF and CRLF forms. It creates the three
unbound profiles and removes recognized retired profiles in one all-or-nothing batch.
Any modified or unknown target aborts before mutation; unrelated custom agents remain
untouched. Failures restore the historical files and line endings. This is installation
failure recovery, not a promise of arbitrary version downgrade.

Windows PowerShell example:

```powershell
$pluginDir = (codex plugin list --json | ConvertFrom-Json).installed |
  Where-Object pluginId -eq 'sol-advisor@sol-advisor' |
  Select-Object -ExpandProperty source |
  Select-Object -ExpandProperty path
$agentDir = Join-Path $env:USERPROFILE '.codex/agents'
# Git for Windows sh; use explicit native paths rather than assuming WSL.
sh "$pluginDir/scripts/install-agents.sh" --target-dir $agentDir --upgrade-managed
sh "$pluginDir/scripts/install-agents.sh" --target-dir $agentDir --check
```

Start a new Codex task after installation so native roles and the bundled Skill are
rediscovered. If a new task still advertises an older cache path, reload Codex Desktop
before creating another task.

Checking out the `3.0.0` release does not update an existing global installation or
plugin cache. Follow the installation steps above. Native smoke tests of the new
role names require a fresh task that loads those profiles; source checks alone do
not establish native behavior acceptance.

## Optional diagnostics

After plugin and agent installation, run the read-only combined check:

```sh
python scripts/check-installation.py
```

Run it from the plugin directory. It checks Codex registration, the cached plugin files
and all three model-independent templates, and reports differences without reinstalling
or overwriting customizations. `--cache PATH` supports offline checks and explicitly
does not verify Codex registration.

These development diagnostics do not gate normal dispatch:

```sh
sh "$plugin_dir/scripts/validate-agent-route.sh" \
  sol_advisor_scout openai gpt-6-luna high trace_boot__gpt_6_luna

sh "$plugin_dir/scripts/inspect-agent-runtime.sh" \
  <native-subagent-thread-id>
```

The route script checks a documented role/model/effort combination. The runtime
inspector accepts both the older top-level identity fields and nested v2
`source.subagent.thread_spawn` identity. It requires non-empty, consistent
`agent_role`, `model`, `effort` and `cwd`; missing or conflicting values are rejected.
Optional `parent_thread_id`, `agent_path` and `model_provider` are emitted as null when
absent; duplicated top-level and nested parent/path values must agree. Only allowlisted
routing fields are emitted. The inspector rejects model or effort changes between
turns; it diagnoses observed routing and does not enable mid-child switching.

## Local development

Install a checkout as a local marketplace:

```sh
cd /absolute/path/to/sol-advisor
codex plugin marketplace add /absolute/path/to/sol-advisor
codex plugin add sol-advisor@sol-advisor
```

Run no-cost checks:

```sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
```

On Windows, run with Git for Windows' POSIX tools first in the shell PATH
(`PATH="/usr/bin:$PATH"`). If multiple Python environments are installed, set
`SOL_ADVISOR_PYTHON` to the intended Python 3.11+ executable. Mixing MSYS Python
with a Windows-first PATH can select Windows `find.exe` instead of POSIX `find`.

The verifier checks model-independent profiles, route rejection, managed installation
and failure recovery, historical upgrades, workspace snapshots, runtime metadata
diagnostics and shell syntax/LF. It invokes no model API or compilation. Static
configuration checks cannot prove role behavior or permissions enforcement.

For workspace-local temporary files, create a disposable directory beneath the checkout
and set TMPDIR (and TEMP/TMP on Windows) before running tests. Installation regression
writes only to isolated targets and removes its own temporary contents.

Native smoke tests should separately exercise discovery, direct evidence transfer,
scoped implementation, leaf behavior and primary takeover in a disposable workspace.
Use freshly loaded `sol_advisor_scout`, `sol_advisor_worker` and
`sol_advisor_reviewer` profiles and report the actual model/effort. Old roles, generic
GPT-6 agents, simulated messages and static checks are not proof of the new profiles.

See [architecture and rationale](docs/architecture-v2.md). Broad cost comparisons are
separate from routine functional checks; no unmeasured speed or quota improvement is claimed.

## License

MIT
