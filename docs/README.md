# 一刻文档

## 产品与体验

| 文档 | 负责什么 |
| --- | --- |
| [产品说明](product.md) | 定位、范围、页面职责与核心使用路径 |
| [逻辑与交互](logic-and-interactions.md) | 业务对象、数据流转、状态机、动作结果、保存恢复与统计 |
| [UI 与动效设计](ui-design.md) | 页面结构、滚动、主题、资源、动效与可访问性 |
| [已知缺口](known-gaps.md) | 实现偏差、待决事项与未验证边界 |

先读产品说明，再按任务阅读逻辑和 UI 文档，实施前核对已知缺口。三份职责文档整理自已批准的一刻产品基线，细化现有要求，不表示 Flutter 页面已实现。

当前 Flutter 第一层与第二层的实施、测试和剩余边界分别见 [弹层自查](reviews/2026-10-22-popup-audit.md)、[第二层自检](reviews/2026-10-22-layer-2.md) 及 [已知缺口](known-gaps.md)。

产品文档直接从本地文件读取，不通过 MCP 获取。后续计划由 Flutter 生成脚本复制到产品 docs；当前由用户手动移动或复制。固定 Handoff 仍通过 MCP 读取结构、截图、Case 和交互证据。文档版本不自动等于 Evidence 版本，冲突须记录来源。

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
| [Agent 工作流](agent-workflow.md) | 先理解与审批、实现、验证和报告 |

产品规则、固定 Evidence 和工程约束各有职责：文档描述要求，Evidence 保留观测事实，工程规范决定实现边界。存在冲突时显式报告，不静默覆盖任一来源。
