# Yike Agent Rules

本工程由 `pnpm pb:new:flutter` 从 flutter_pb_app 基线生成，是独立的 **yike** 产品 target，不是 ProtoBridge 仓库。`lib/features/` 为空；业务页面由固定 PBWork Handoff 按 Screen 落在这里。

MCP 已由 `.cursor/mcp.json`、`.codex/config.toml`、`.mcp.json` 指向 `tool/mcp.mjs`；不要修改 proto-bridge producer，也不要在目标工程复制 Evidence Store。

收到固定 Evidence 时先读 `.agents/skills/proto-bridge-consumer/SKILL.md`；DS 同步任务读 `.agents/skills/proto-bridge-ds-target-sync/SKILL.md`；完成实现准备 Review 时读 `.agents/skills/acceptance/SKILL.md`。

## 文档优先级

产品要求直接读取本地 `docs/README.md`、`docs/product.md`、`docs/logic-and-interactions.md`、`docs/ui-design.md` 与 `docs/known-gaps.md`，不通过 MCP 获取产品文档。产品说明表达要求，固定 Evidence 保留实际观测；发生冲突时记录双方来源，不静默覆盖，也不将文档中的动效意图宣称为已观测过程。

1. 固定 ProtoBridge Evidence 决定源页面的结构、文案、状态、交互和构图。
2. 本工程 `AGENTS.md`、`docs/` 和实际代码决定 Target 落点、组件、Theme、路由与验证方式。
3. Target adapter 结果只提供目标上下文，不能覆盖 Screenshot、Fragment、Case 或 revision。

## 修改边界

- 业务页面和页面模型放在 `lib/features/<feature>/`。
- 所有响应式界面状态使用 Riverpod；禁止 `setState` / `StatefulBuilder`，公共组件、Demo 和启动页均无例外，详见 `docs/architecture.md`。
- 持久化只走 `AppPrefs`；feature 不得直接使用 `MMKV`。
- 路由常量和注册表只放在 `lib/router/`。
- 主题和语义 token 只放在 `lib/theme/`。
- 可复用 UI 和共享弹层只放在 `lib/common/`。
- 不在 feature 中复制公共组件、创建平行 Theme 或绕过既有路由/弹层边界。

## 第一轮纪律

拿到 PBWork 提示词后，先读 `AGENTS.md`、`README.md`、`docs/` 和 Consumer Skill；只读理解 Evidence 与目标工程，按 Screen 用简短散文输出结构/滚动边界、组件与 Token 落点、状态与交互覆盖、预计修改文件、验证方式和剩余风险；然后暂停等待明确批准。未批准前不得修改本工程。

## 必要验证

```bash
flutter analyze
flutter test
node tool/verify.mjs
node tool/ds-theme.mjs
# 完整组件与 Token 同步门禁
node tool/ds-sync.mjs
```

主题门禁检查当前 Token 清单；完整 `ds-sync.mjs` 同时检查当前组件清单与当前 DS surface。共享组件扩展必须遵循当前 Contract 和目标工程规范；映射成功不等于视觉验收通过。

视觉验证遵循 `docs/testing.md`；最终报告必须包含固定引用、原始风险、修改文件、验证结果、已知偏差和剩余风险。
