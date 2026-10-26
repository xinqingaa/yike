# Flutter 独立迭代

日期：2026-10-23。用户确认首轮迁移成果，后续以 Flutter 独立迭代为主；六阶段功能现已全部完成。

产品与工程规则在本仓库维护，日常工作不读取 PBWork / Vue 或调用 ProtoBridge MCP。只有明确要求原型迁移、固定证据或 DS 同步时进入专项；旧映射不自动限制后来获批的产品变化。

延续 feature、Riverpod、AppPrefs 和局部 Controller / Ticker 边界，客户端检查独立于 Producer。未明确的产品体验由用户决定，普通工程细节按规范自主落实。实施授权与 Git 提交 / 推送授权分开，见 [工作流](../workflow.md)。
