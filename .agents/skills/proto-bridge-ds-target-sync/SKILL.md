---
name: proto-bridge-ds-target-sync
description: >-
  Synchronize the stable PBWork Design System contract, roles, tokens, themes,
  components, and interactions into this Flutter target without a Handoff.
---

# PBWork DS → Flutter 同步

本 Skill 只处理 Design System 目标适配，不读取或伪造 Handoff。开始时先读：

1. `AGENTS.md`
2. `docs/proto-bridge.md`
3. 根目录 `proto-bridge.target.json`
4. 根目录 `proto-bridge.sync.json`
5. `docs/components.md`、`docs/theme.md` 与 `docs/assets.md`
6. Producer 的 `../../../../proto-bridge/apps/pbwork/docs/components/alignment-protocol.md` 及本批变化 Contract

## 流程

1. 主题批次运行 `node tool/ds-theme.mjs`，组件批次运行 `node tool/ds-sync.mjs`；记录 Schema、Contract、role、Token/Theme 变化分区和组件，不要凭记忆决定同步范围。
2. 先按任务确定全量或原型范围；主题范围记录在 `proto-bridge.themes.json`，图标范围记录在 `proto-bridge.icons.json`，核对每个主题与模式的生成实现，不能只更新 fingerprint。默认全量；指定原型时选择绑定主题包及继承依赖。
   图标同步先读 Producer 的 `../../../../proto-bridge/apps/pbwork/docs/components/action/icon.md`；从同一 DS SVG 源导出图片和 Dart 名称，不手工补 PNG 或枚举；SVG 只在 Producer 维护，Target 只接收 PNG，不能复制原稿或另建参考副本目录。指定原型时同时限制主题与图标范围。
3. 按 `componentId` 翻译职责、`summary`、`behavior`、state kind、layout、visual anatomy 和 token bindings。Role 只做通用语义回退；例如 `flow-sheet` 仍使用 `sheet` role。
4. 更新 Target 自己拥有的根目录 `proto-bridge.target.json` 与 Dart 公开 API。允许 API 不同构，但当前登记的 Contract id 与完整 Token Catalog 都必须被 resolver 判定为 `resolved`，或在 `proto-bridge.target.json` 中以带非空 `reason` 的条目 `pending` 显式声明（条目状态，与 `proto-bridge.sync.json` 的批次 `pending` 是两个概念，见 `docs/proto-bridge.md`）；未声明又缺失的键仍然失败，不得保留旧 id 或旧 Dart API 兼容层。
5. 平台近似必须显式记录；不得在 feature 中复制公共组件或创建平行 Theme。所有响应式状态按 `docs/architecture.md` 使用 Riverpod，公共组件与 Demo 无例外；弹层按库示例组合，不复制定位算法。
6. 依赖使用 pub.dev 的 unified_popups，不添加本地 path 或 override；存储只用 MMKV，主题只用类型化 AppThemePack / TS ThemeExtension，不保留旧主题或旧存储实现。
7. DS 仍在连续迭代时保持 drift/pending 可见；确认稳定后用 verifier 输出更新根目录 `proto-bridge.sync.json`，状态恢复 `synced`。

## 验证

```bash
flutter analyze
flutter test
node tool/ds-sync.mjs
```

交付报告说明同步 surface、组件/Token resolver 覆盖率、验证输出列出的条目 `pending` 清单与 reason、平台近似和剩余偏差。
