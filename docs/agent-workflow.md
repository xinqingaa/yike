# Agent 工作流

本工程已经带好 MCP 配置和 target 文档，agent 不需要重新拼 proto-bridge 路径。

## 第一轮

1. 读 `AGENTS.md`、`README.md`、[文档索引](README.md) 和 Consumer Skill。先从本地读取 [产品说明](product.md)、[逻辑与交互](logic-and-interactions.md)、[UI 与动效](ui-design.md) 与 [已知缺口](known-gaps.md)，不通过 MCP 获取产品文档。
   本地文档描述产品要求，不代表已经观测或已实现；与固定 Evidence 冲突时保留双方来源并报告。
2. 调用 `inspect_evidence_workspace`，确认 `deliveryTargetRoot` 指向本目录；不一致就停止并报告。
3. 按固定 Handoff 读取 index、Screen packet、不同 digest 的 Screenshot、Case delta。
4. 调用 `inspect_target_readiness`；组件/Token 的 `pending` 必须披露，不得替换实现。
5. 每个 Screen 用简短散文写 Evidence 理解摘要和实现计划，然后暂停等待批准。

## 批准后

- 只在 `lib/features/<feature>/` 落业务页面；路由写 `lib/router/`。
- 复用 `lib/common/`、`lib/theme/` 和既有路由/弹层边界。
- 运行 `node tool/verify.mjs`；视觉验收按 `docs/testing.md`。
- 完成后按 `.agents/skills/acceptance/SKILL.md` 做五维 Review，不把 self-report 当成最终视觉验收。

## 不要做

- 不要修改 proto-bridge producer。
- 不要在 feature 中复制公共组件或新建平行 Theme。
- 不要把 `pending` 组件/Token 当成 resolved，也不要用通用 widget 静默替代。
