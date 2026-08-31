# Project Plans

> Managed project-level plans only. Routine bugs, implementation tasks, and development journals do not belong here.

<!-- PROJECT_PLAN_DATA_START -->
```json
{
  "schemaVersion": 1,
  "plans": [
    {
      "id": "P001",
      "title": "受控 A/B 评估子代理准确性与全流程成本",
      "summary": "比较同一源码任务下主窗口单独执行、子代理原始结果及主窗口整合结果，分离准确性、证据保留、上下文、Token 与延迟收益。历史六组无索引实验已有部分执行记录，尚未核实完整盲评和最终报告；本次仅恢复计划，不重启实验。",
      "status": "in-progress",
      "successCriteria": [
        "在同一源码快照、业务提示、主模型与推理强度下进行独立 A/B；六例覆盖精确查找、启动调用链、编译变体、跨层输出、初始化依赖和错误前提反证。",
        "分别评分 A、各 child、B-child aggregate 与 B-final，记录可核验定位、错误拦截和证据遗漏；原生 Token 不可得时记 N/A，不用字符估算。",
        "形成逐例准确性、父/子/总 Token、总耗时、实际路由及成本收益报告；业务源码和 SVN 属性不得变化。"
      ],
      "specRefs": [],
      "decisions": [
        "来源任务：D:\\Github_Fork\\sol-advisor 这个仓库的原地址是什么；thread=019fcabe-6cb5-7042-806a-66f960402ccf，turn=019fe034-36d8-7883-9c44-70471e826d95；用户明确要求设计效果与准确性对比测试。",
        "执行来源：Sol Advisor 无索引 A/B 执行与评估；thread=019fe052-f70f-77f1-a587-5e2aa3ab88cb，最新可读 turn=019fe0b1-608f-7003-be1a-437b1dc02016，为 interrupted，仅可见 C05-B 收尾及准备 C06-B，不视为完成。",
        "历史目标为 E:\\SVN\\ZEEKE\\GEEA_CC1E\\Project\\trunk\\03_code\\ZEEKR_CC1E_App\\ZEEKR_CC1E_Front_App；revision 89078、11 个 Source Insight 修改与无索引状态仅为当时记录，恢复执行前必须重新核验。",
        "历史控制方案为 sol/medium 父窗口、六组交替 A/B、两名独立盲评；评分权重 30/25/15/10/10/10。旧门槛含关键 locator≥95%、复杂任务平均提升≥5 分、证据保留≥90%、父上下文减少≥20%。这些是旧实验指标，不代表当前版本已达标。",
        "当前 README.md 与 plugins/sol-advisor/skills/orchestration/SKILL.md 已使用原生 final，旧 plans/state/results/visible/runtime 和 sidecar 校验规则已不适用。新实验须先冻结当前版本协议和实际路由，不把旧预期模型当作现行硬规则。",
        "下一步先核对历史原始结果、缺失用例和评分，再制定适配当前版本的实验方案。新增高成本运行或写入外部目标前需确认；有索引第二轮仅保留为建议，本次不执行。"
      ],
      "createdAt": "2026-08-31T02:19:35.621Z",
      "updatedAt": "2026-08-31T02:19:48.441Z",
      "transitions": [
        {
          "from": null,
          "to": "proposed",
          "reason": "Plan recorded.",
          "at": "2026-08-31T02:19:35.621Z"
        },
        {
          "from": "proposed",
          "to": "accepted",
          "reason": "用户在任务 019fcabe-6cb5-7042-806a-66f960402ccf 明确要求 A/B 测试设计，关联执行任务 019fe052-f70f-77f1-a587-5e2aa3ab88cb 已开展实验；这里只恢复既有方向。",
          "at": "2026-08-31T02:19:48.168Z"
        },
        {
          "from": "accepted",
          "to": "in-progress",
          "reason": "历史执行任务可读记录已推进到 C05-B 并准备 C06-B，但最后回合 interrupted，未见完整盲评和最终报告；表示历史工作未收口，不表示当前有运行任务。",
          "at": "2026-08-31T02:19:48.441Z"
        }
      ],
      "dedupeKey": "sha256:5aa0eb436c1428ec3ca2ed624298423ec035a582d263e7a5cc3d4c5e216c1b4e"
    },
    {
      "id": "P002",
      "title": "主窗口确认有效性的项目证据复用",
      "summary": "保留并筛选可复用证据，减少重复搜索和过期信息污染；由主窗口确认有效性，再定向提供给后续任务。用户已认可此方向并明确延后实施；具体存储、检索技术和跨插件职责尚未定案。",
      "status": "accepted",
      "successCriteria": [
        "证据的有效性由主窗口确认，保留来源、适用范围、版本及失效或弃用原因。",
        "仅复用与当前任务相关且仍有效的证据；已失效、被替代或被否定的信息不得当作当前事实注入。",
        "实施前明确与 Codex Project Context 的职责分界，不让 Sol Advisor 写入 AGENTS.md 或 .agent 上下文、计划和交接文件。"
      ],
      "specRefs": [],
      "decisions": [
        "来源任务：D:\\Github_Fork\\sol-advisor 这个仓库的原地址是什么；thread=019fcabe-6cb5-7042-806a-66f960402ccf，turn=019fdfc9-3bc6-7e00-bc5e-bdc8a6d0c6c3；用户认可原始证据→主窗口验证/去重/标记/压缩→有效性判断→必要证据注入，并说明属于后续增加内容。",
        "用户确认的是证据复用方向与主窗口确认责任，并未确定 RAG、Mem0、Graphiti 或具体数据库；不把历史助手建议视为技术选型决定。",
        "当前依据：README.md 明确 Sol Advisor 不拥有项目持久上下文；plugins/sol-advisor/skills/orchestration/SKILL.md 禁止运行期 sidecar。历史 .git/sol-advisor/evidence 目录建议不可直接照搬。",
        "下一步在用户启动此方向时界定最小证据记录、失效判断与所属插件，之后再选检索实现；本次不安装依赖、不创建证据库、不修改编排流程。"
      ],
      "createdAt": "2026-08-31T02:19:36.257Z",
      "updatedAt": "2026-08-31T02:19:48.711Z",
      "transitions": [
        {
          "from": null,
          "to": "proposed",
          "reason": "Plan recorded.",
          "at": "2026-08-31T02:19:36.257Z"
        },
        {
          "from": "proposed",
          "to": "accepted",
          "reason": "用户在 turn 019fdfc9-3bc6-7e00-bc5e-bdc8a6d0c6c3 认可证据复用流程并明确主窗口确认有效性，同时要求延后实施；当前只记录方向，不启动实现。",
          "at": "2026-08-31T02:19:48.711Z"
        }
      ],
      "dedupeKey": "sha256:36cb7c9467d50b862064b61aaf2533d587dcc98129c66bc1dc24ca8c1ee152a7"
    }
  ]
}
```
<!-- PROJECT_PLAN_DATA_END -->

## P001 受控 A/B 评估子代理准确性与全流程成本

- Status: `in-progress`
- Updated: 2026-08-31T02:19:48.441Z
- OpenSpec references: none

比较同一源码任务下主窗口单独执行、子代理原始结果及主窗口整合结果，分离准确性、证据保留、上下文、Token 与延迟收益。历史六组无索引实验已有部分执行记录，尚未核实完整盲评和最终报告；本次仅恢复计划，不重启实验。

### Success Criteria

- 在同一源码快照、业务提示、主模型与推理强度下进行独立 A/B；六例覆盖精确查找、启动调用链、编译变体、跨层输出、初始化依赖和错误前提反证。
- 分别评分 A、各 child、B-child aggregate 与 B-final，记录可核验定位、错误拦截和证据遗漏；原生 Token 不可得时记 N/A，不用字符估算。
- 形成逐例准确性、父/子/总 Token、总耗时、实际路由及成本收益报告；业务源码和 SVN 属性不得变化。

### Decisions

- 来源任务：D:\Github_Fork\sol-advisor 这个仓库的原地址是什么；thread=019fcabe-6cb5-7042-806a-66f960402ccf，turn=019fe034-36d8-7883-9c44-70471e826d95；用户明确要求设计效果与准确性对比测试。
- 执行来源：Sol Advisor 无索引 A/B 执行与评估；thread=019fe052-f70f-77f1-a587-5e2aa3ab88cb，最新可读 turn=019fe0b1-608f-7003-be1a-437b1dc02016，为 interrupted，仅可见 C05-B 收尾及准备 C06-B，不视为完成。
- 历史目标为 E:\SVN\ZEEKE\GEEA_CC1E\Project\trunk\03_code\ZEEKR_CC1E_App\ZEEKR_CC1E_Front_App；revision 89078、11 个 Source Insight 修改与无索引状态仅为当时记录，恢复执行前必须重新核验。
- 历史控制方案为 sol/medium 父窗口、六组交替 A/B、两名独立盲评；评分权重 30/25/15/10/10/10。旧门槛含关键 locator≥95%、复杂任务平均提升≥5 分、证据保留≥90%、父上下文减少≥20%。这些是旧实验指标，不代表当前版本已达标。
- 当前 README.md 与 plugins/sol-advisor/skills/orchestration/SKILL.md 已使用原生 final，旧 plans/state/results/visible/runtime 和 sidecar 校验规则已不适用。新实验须先冻结当前版本协议和实际路由，不把旧预期模型当作现行硬规则。
- 下一步先核对历史原始结果、缺失用例和评分，再制定适配当前版本的实验方案。新增高成本运行或写入外部目标前需确认；有索引第二轮仅保留为建议，本次不执行。

### Status History

- 2026-08-31T02:19:35.621Z: created -> proposed — Plan recorded.
- 2026-08-31T02:19:48.168Z: proposed -> accepted — 用户在任务 019fcabe-6cb5-7042-806a-66f960402ccf 明确要求 A/B 测试设计，关联执行任务 019fe052-f70f-77f1-a587-5e2aa3ab88cb 已开展实验；这里只恢复既有方向。
- 2026-08-31T02:19:48.441Z: accepted -> in-progress — 历史执行任务可读记录已推进到 C05-B 并准备 C06-B，但最后回合 interrupted，未见完整盲评和最终报告；表示历史工作未收口，不表示当前有运行任务。

## P002 主窗口确认有效性的项目证据复用

- Status: `accepted`
- Updated: 2026-08-31T02:19:48.711Z
- OpenSpec references: none

保留并筛选可复用证据，减少重复搜索和过期信息污染；由主窗口确认有效性，再定向提供给后续任务。用户已认可此方向并明确延后实施；具体存储、检索技术和跨插件职责尚未定案。

### Success Criteria

- 证据的有效性由主窗口确认，保留来源、适用范围、版本及失效或弃用原因。
- 仅复用与当前任务相关且仍有效的证据；已失效、被替代或被否定的信息不得当作当前事实注入。
- 实施前明确与 Codex Project Context 的职责分界，不让 Sol Advisor 写入 AGENTS.md 或 .agent 上下文、计划和交接文件。

### Decisions

- 来源任务：D:\Github_Fork\sol-advisor 这个仓库的原地址是什么；thread=019fcabe-6cb5-7042-806a-66f960402ccf，turn=019fdfc9-3bc6-7e00-bc5e-bdc8a6d0c6c3；用户认可原始证据→主窗口验证/去重/标记/压缩→有效性判断→必要证据注入，并说明属于后续增加内容。
- 用户确认的是证据复用方向与主窗口确认责任，并未确定 RAG、Mem0、Graphiti 或具体数据库；不把历史助手建议视为技术选型决定。
- 当前依据：README.md 明确 Sol Advisor 不拥有项目持久上下文；plugins/sol-advisor/skills/orchestration/SKILL.md 禁止运行期 sidecar。历史 .git/sol-advisor/evidence 目录建议不可直接照搬。
- 下一步在用户启动此方向时界定最小证据记录、失效判断与所属插件，之后再选检索实现；本次不安装依赖、不创建证据库、不修改编排流程。

### Status History

- 2026-08-31T02:19:36.257Z: created -> proposed — Plan recorded.
- 2026-08-31T02:19:48.711Z: proposed -> accepted — 用户在 turn 019fdfc9-3bc6-7e00-bc5e-bdc8a6d0c6c3 认可证据复用流程并明确主窗口确认有效性，同时要求延后实施；当前只记录方向，不启动实现。
