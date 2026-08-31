# Project Rules

- 先给结论，回复简短，不重复背景，不输出冗长推理；复杂任务持续执行，按“发现 / 下一步 / 阻塞”简短汇报。
- 缺少影响方案、范围、安全或验证的关键信息时，先自行检查代码、文档、配置、日志或测试；仍无法确认时，只问最关键的问题并停止执行，不猜测。
- 修改前阅读相关实现并确认影响范围；Bug 先找最短复现路径。只做必要的最小修改，不增加额外功能、不重构无关代码、不撤销用户修改。
- 优先运行最小相关验证；没有验证证据，不得声称成功。历史聊天中的完成声明必须与当前项目证据区分。
- 删除文件、修改 Git 历史、强制推送、生产环境或高成本操作前，说明影响并等待确认；历史任务中的单次授权不作为本次执行授权。
- 禁止对本工程受控文件使用 `perl -pi`、`sed -i`、`unix2dos`、`dos2unix`、PowerShell/Python 整文件读写、删除后重建等整文件重写方式；使用局部补丁并保持原有编码与换行。
- `.codegraph/` 已存在时，理解或定位代码先使用 CodeGraph；无覆盖或明确报告索引不可用、过期时，再对相关文件做精确检索和读取。不擅自重建索引。
- `.codegraph/`、`.serena/` 是本地分析资产，不混入功能修改或提交；不修改全局 Codex 配置、已安装插件缓存或其他项目，除非本次任务明确要求。
- 最终按需报告“结果 / 修改文件 / 验证 / 风险 / 推荐”。

<!-- PROJECT_CONTEXT_START -->
# Project Agent Instructions

This managed section is the stable execution map for Codex in this project.
Use current code, configuration, specifications, and observed test output as evidence; never invent missing project facts.

## Project Overview

- sol-advisor-auto 是独立的 Sol Advisor Codex 插件仓库;插件元数据与市场入口分别位于插件 manifest 和 .agents/plugins/marketplace.json。
- 主要实现由 Markdown 编排技能与角色契约、七个 TOML 原生代理模板、Shell 安装及校验脚本和 Python 搜索预检组成。
- 编排以准确性和一次完成率为硬门槛,再比较全流程成本;主窗口拥有未决设计、验证和集成,子代理承接有界职责。
- 当前运行期使用原生子代理状态与普通 final,不创建 dispatch/state/result sidecar;Python 仅用于开发期静态校验等辅助工作。
- 搜索预检支持 Git、SVN 与普通目录;插件本身不拥有用户或项目的 AGENTS.md、.agent 上下文和授权文件。

## Build and Verification

- 可进行与修改范围一致的只读分析及本地低成本校验;涉及文件删除、生产环境或高成本测试,先说明影响并取得确认。
- 本地代理安装和受管升级会写入目标配置;除非当前任务已授权,不执行安装、缓存重装或全局配置更新。未知或用户修改的模板不得覆盖。
- 验证结论必须注明静态检查、真实子代理调用或外部项目实验的证据范围,不能用历史完成声明替代当前验证。

## Code Analysis

- 现有 .codegraph/ 用于优先定位代码及影响范围;无覆盖时,对 Markdown、TOML、JSON、Shell 文本作有界精确读取。
- 已有 .serena/project.yml,符号和引用分析可使用 Serena;工具不可用时回退普通检索,不自动刷新或重建索引。
- 角色或路由变更需对照编排 Skill、对应角色契约、TOML 模板、路由校验和回归夹具;Shell 文件保持 LF。

## Project References

- documentation: `README.md` — 插件能力、职责边界、安装方式与运行生命周期。
- documentation: `plugins/sol-advisor/skills/orchestration/references/role-contracts.md` — 角色契约索引;仅按具体任务继续读取对应角色。
- test: `plugins/sol-advisor/scripts/verify.sh` — 仓库静态、模板、路由与升级兼容性回归验证入口。

- README 说明整体行为,角色契约约束单个职责,校验脚本证明已覆盖的静态边界;历史聊天仅作决策来源,冲突时核对当前实现。


## Project Context

- `.agent/context.json`: stable project metadata and context configuration.
- `.agent/planMsg.md`: confirmed project-level plans and key decisions, created only when needed.
- `.agent/handoff/`: cross-task handoff index and records.

## Sol Advisor Integration

- This project inherits global Sol Advisor eligibility, subject to the installed Skill's quality and benefit gates.
- Policy comes from schema-v1 `.agent/authorizations.json`: a missing file or key inherits the global default, `true` allows, and `false` disables implicit delegation.
- Invalid or unreadable policy fails closed to primary-only work; explicit current-user instructions override project defaults.
- Sol Advisor may read this policy but must not modify `AGENTS.md` or any `.agent` context, authorization, plan, or handoff file.
- If Sol Advisor or a required role is unavailable, continue in the primary session without substitution and without blocking ordinary project work.

## Handoff Context

- Create a handoff only when coherent work must continue in another task; skip routine questions and one-off small changes.
- 按插件能力、角色契约、代理模板、安装升级、静态验证和相关文件匹配交接;保留来源、验证范围及未完成事项。
- If no reliable match exists, continue from the current project without forcing historical context or reading unrelated records.
- Use handoffs only to restore the objective, confirmed progress, verification, remaining work, and risks; current code, configuration, references, and test evidence remain authoritative.
<!-- PROJECT_CONTEXT_END -->
