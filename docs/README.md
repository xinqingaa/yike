# 一刻文档

产品文档描述应用应有的行为；[已知缺口](known-gaps.md) 记录当前实现状态和待决事项。项目介绍与运行方式见 [根 README](../README.md)。

## 产品与体验

| 文档 | 负责什么 |
| --- | --- |
| [产品说明](product.md) | 定位、范围、页面职责与核心使用路径 |
| [逻辑与交互](logic-and-interactions.md) | 业务对象、数据流转、状态机、动作结果、保存恢复与统计 |
| [UI 与动效设计](ui-design.md) | 页面结构、滚动、主题、资源、动效与可访问性 |

## 工程规范

| 文档 | 负责什么 |
| --- | --- |
| [工程架构](architecture.md) | 分层、Riverpod、持久化与 feature 边界 |
| [组件](components.md) | Common 组件、公开入口和共享弹层 |
| [Theme 与 Token](theme.md) | 主题模型、语义取值与视口适配 |
| [静态资源](assets.md) | DS 资源导出、目录、清单与复用 |
| [路由](routing.md) | 路由常量、注册和参数 |
| [测试](testing.md) | 原生检查、场景和移动视觉验证 |
| [ProtoBridge 适配](proto-bridge.md) | Evidence 到组件/Token 的映射和同步验证 |

## 协作与状态

| 文档 | 负责什么 |
| --- | --- |
| [协作与工作流](workflow.md) | 阅读顺序、审批、Evidence 与 MCP 使用、任务 Skill、交付要求 |
| [已知缺口](known-gaps.md) | 未完成能力、实现偏差、产品待决与验证边界 |
| [页面交付记录](reviews/2026-10-22-layer-1.md) | 初次页面交付的固定引用、范围与阶段结果 |
| [修复记录](reviews/2026-10-22-repair.md) | 后续布局、主题和交互修复的历史验证 |
| [弹层自查](reviews/2026-10-22-popup-audit.md) | 弹层修复范围及其验证记录 |
| [布局与交互精修](reviews/2026-10-23-layout-polish.md) | 数字居中、倒计时网格、计圈与每日记录、日期点击反馈、可选步骤指示 |
| [Flutter 体验修复](reviews/2026-10-23-flutter-experience.md) | 字体插值、滚轮、热力图、回顾与弹层交互及移动截图 |
| [本地业务自检](reviews/2026-10-22-layer-2.md) | 计时、习惯、统计与快照恢复的实施和历史验证 |
