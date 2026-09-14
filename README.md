# Sol Advisor

Version `2.0.1` is a lightweight native-agent collaboration plugin: three
responsibilities, four model-specific profiles, host-dependent teammate messaging, and an
ordinary final response. Keep small tasks local; delegate substantial independent
work when it improves quality or total completion time.

## Roles and models

| Native agent type | Model | Default effort |
|---|---|---|
| `sol_advisor_scout__gpt_5_6_luna` | GPT-5.6 Luna | high; xhigh for difficult tracing |
| `sol_advisor_worker__gpt_5_6_sol` | GPT-5.6 Sol | medium; high for difficult implementation |
| `sol_advisor_reviewer__gpt_5_6_sol` | GPT-5.6 Sol | high |
| `sol_advisor_reviewer__gpt_6_astra` | GPT-6 Astra | xhigh for critical review |

Scout investigates bounded code or source questions, including unknown file locations.
Worker owns scoped implementation, local design, debugging and authorized checks.
Reviewer independently examines implementation, design or conflicting evidence without
implementing fixes. Review is optional, not a stage added to every edit.

The current primary session remains coordinator and final owner. Astra medium is a
recommended primary configuration, not an automatic model switch. Templates pin their
named model; select effort at dispatch. Use instance names such as
`trace_boot__gpt_5_6_luna`. A different model needs its matching profile.

## Native collaboration

Give a short assignment with task, owned scope, completion condition and essential
context/restrictions. Scout defaults to `fork_turns: "none"`; other narrow tasks
also benefit from fresh context, while limited inheritance may suit shared decisions.
Respect the host's context and model-override rules.

Assignments specify the communication path. Where the host exposes native messaging,
teammates send evidence and questions directly. Otherwise children return evidence
in ordinary finals and the primary forwards it with source attribution in follow-ups.
Codex app thread messaging is not a substitute for native agent messaging.
No registered dependency graph or message schema is required. Children
remain leaves: they do not spawn or manage other agents. Messages do not grant new
authority or automatically reactivate an ended child.

Use one writer per conflicting file/resource, preserve user changes, and avoid duplicate
investigation. Shared test output and hardware also need exclusive ownership. The
primary continues disjoint work, handles scope changes and confirms work has stopped
before takeover. Continue a useful child while it makes progress; no fixed correction
count is imposed.

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

跨模块调查、多项独立验证或重要结论争议，应先评估有界分工，无需用户点名代理。
证据范围和停止条件清晰、可独立推进，且能并行推进其他必要工作、压缩大量调查上下文，
或独立纠正具体重要争议时，按“质量收益或总耗时收益”判断，任一收益明确即可委派。
简单任务默认由主会话完成；复杂度结合推理不确定性、证据量、依赖和错误后果判断。
质量收益不要求同时提速；时间收益不要求额外提高质量，但仍须满足正确性和验收要求。
时间估计须包含启动、上下文交接、等待、复核和集成开销，并行本身不等于提速。
用户指定的期限、预算和授权仍须遵守，不额外给质量收益路线添加时间上限。
“主会话能完成”本身不否定满足任一收益的分工；两者均无明确收益时留在主会话。
数量受任务收益及宿主、项目上限约束，插件不固定最多一个，也不要求每个角色都运行。

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
files. Install the four model-specific native templates separately:

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

Managed upgrade recognizes exact historical template hashes, including 1.0.2, in LF
and CRLF forms. It creates the four new profiles and removes recognized retired
profiles in one batch. Any modified or unknown target aborts before mutation;
unrelated custom agents remain untouched. Failures roll back the batch. This is
installation failure recovery, not a promise of arbitrary version downgrade.

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

## Optional diagnostics

After plugin and agent installation, run the read-only combined check:

```sh
python scripts/check-installation.py
```

Run it from the plugin directory. It checks Codex registration, the cached plugin files
and all four model-specific templates, and reports differences without reinstalling or
overwriting customizations. `--cache PATH` supports offline checks and explicitly does
not verify Codex registration.

These development diagnostics do not gate normal dispatch:

```sh
sh "$plugin_dir/scripts/validate-agent-route.sh" \
  sol_advisor_scout__gpt_5_6_luna openai gpt-5.6-luna high trace_boot__gpt_5_6_luna

sh "$plugin_dir/scripts/inspect-agent-runtime.sh" \
  <native-subagent-thread-id>
```

The route script checks a documented role/model/effort combination. The runtime
inspector emits only allowlisted routing fields and rejects a thread whose model or
effort changes between turns.

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

The verifier checks model/profile consistency, mismatched route rejection, managed
installation and failure recovery, historical upgrades, workspace snapshots, runtime
metadata diagnostics and shell syntax/LF. It invokes no model API or compilation.
Static configuration checks cannot prove role behavior or permissions enforcement.

For workspace-local temporary files, create a disposable directory beneath the checkout
and set TMPDIR (and TEMP/TMP on Windows) before running tests. Installation regression
writes only to isolated targets and removes its own temporary contents.

Native smoke tests should separately exercise discovery, direct evidence transfer,
scoped implementation, leaf behavior and primary takeover in a disposable workspace.
Use the newly loaded model-specific profiles and report the actual model/effort.
Do not count old roles, simulated messages or static checks as those tests.

See [architecture and rationale](docs/architecture-v2.md). Broad cost comparisons are
separate from routine functional checks; no unmeasured speed or quota improvement is claimed.

## License

MIT
