# Yike

`yike` 是从 flutter_pb_app 生成的产品 target 骨架。它继承 PBWork 主题/Token、公共组件、路由和测试底座，`lib/features/` 为空，等待固定 PBWork Handoff 落业务页面。

## 快速开始

```bash
flutter pub get
flutter analyze
flutter test
node tool/verify.mjs
flutter run -d <device>
```

## MCP

MCP 已配置在 `.cursor/mcp.json`、`.codex/config.toml`、`.mcp.json`，统一指向 `tool/mcp.mjs`。Codex 需要 trust 本目录后才会加载项目级配置。

PBWork 提示词里的目标路径必须与本目录一致；不一致时先运行：

```bash
node tool/target.mjs --bind
```

## 文档

先读 [文档索引](docs/README.md)、[产品说明](docs/product.md)、[逻辑与交互](docs/logic-and-interactions.md)、[UI 与动效](docs/ui-design.md) 和 [已知缺口](docs/known-gaps.md)。产品文档本地读取，不通过 MCP 获取。

- [工程架构](docs/architecture.md)
- [组件](docs/components.md)
- [Theme 与 Token](docs/theme.md)
- [路由](docs/routing.md)
- [测试](docs/testing.md)
- [ProtoBridge 目标适配](docs/proto-bridge.md)
- [Agent 工作流](docs/agent-workflow.md)

## 验证

`node tool/ds-theme.mjs` 验证当前 Token 清单；`node tool/ds-sync.mjs` 同时验证当前组件清单与当前 DS surface。
