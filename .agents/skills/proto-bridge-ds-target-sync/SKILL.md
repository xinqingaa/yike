---
name: proto-bridge-ds-target-sync
description: >-
  Synchronize the stable PBWork Design System contract, roles, tokens, themes,
  components, and interactions into this Flutter target without a Handoff.
---

# PBWork DS → Flutter 同步

本 Skill 只处理 Design System 目标适配，不读取或伪造 Handoff。通用协作和工程边界遵守 [协作与工作流](../../../docs/workflow.md)；同步前读取：

1. [目标适配](../../../docs/proto-bridge.md) 与根目录 `proto-bridge.target.json`、`proto-bridge.sync.json`。
2. [公共组件](../../../docs/components.md)、[Theme](../../../docs/theme.md) 与 [资源规范](../../../docs/assets.md)。
3. Producer 的 `apps/pbwork/docs/components/alignment-protocol.md` 及本批变化 Contract；Producer 根目录按项目 `.pb-scaffold.json` 解析。

## 流程

1. 主题批次运行 `node tool/ds-theme.mjs`，组件批次运行 `node tool/ds-sync.mjs`；记录 Schema、Contract、role、Token/Theme 变化分区和组件，不要凭记忆决定同步范围。
2. 先按任务确定全量或原型范围；主题范围记录在 `proto-bridge.themes.json`，图标范围记录在 `proto-bridge.icons.json`，核对每个主题与模式的生成实现，不能只更新 fingerprint。默认全量；指定原型时选择绑定主题包及继承依赖。
   主题导出在 Producer 根目录运行 `node scripts/export-flutter-themes.mjs`；图标导出使用 `node scripts/export-flutter-icons.mjs`，先读同目录下 `apps/pbwork/docs/components/action/icon.md`。两者都支持 `--prototype <id>` 与 `--target <directory>`；指定原型时同时限制主题与图标范围。导出必须来自同一 DS SVG 源，文件和颜色策略遵守资源规范。
3. 按 `componentId` 翻译职责、`summary`、`behavior`、state kind、layout、visual anatomy 和 token bindings。Role 只做通用语义回退；例如 `flow-sheet` 仍使用 `sheet` role。
4. 更新 Target 自己拥有的根目录 `proto-bridge.target.json` 与 Dart 公开 API。允许 API 不同构，但当前登记的 Contract id 与完整 Token Catalog 都必须被 resolver 判定为 `resolved`，或在 `proto-bridge.target.json` 中以带非空 `reason` 的条目 `pending` 显式声明（条目状态，与 `proto-bridge.sync.json` 的批次 `pending` 是两个概念，见 `docs/proto-bridge.md`）；未声明又缺失的键仍然失败，不得保留旧 id 或旧 Dart API 兼容层。
5. 平台近似显式记录；同步不复制原型业务页面，真实业务落点由本工程架构决定。
6. 依赖使用 pub.dev 的 unified_popups，不添加本地 path 或 override；弹层按库示例组合，不复制定位算法。存储和主题分别遵守工程架构与 Theme 规范。
7. DS 仍在连续迭代时保持 drift/pending 可见；确认稳定后用 verifier 输出更新根目录 `proto-bridge.sync.json`，状态恢复 `synced`。

## 验证

按 [测试与视觉验证](../../../docs/testing.md) 执行分析、测试与完整 DS 门禁。

交付报告说明同步 surface、组件/Token resolver 覆盖率、验证输出列出的条目 `pending` 清单与 reason、平台近似和剩余偏差。
