# 一刻文档

本索引按产品能力和工程职责组织文档。项目运行与打包入口见 [README](../README.md)，Agent 入口见 [AGENTS](../AGENTS.md)。

## 产品与体验

| 文档 | 职责 |
| --- | --- |
| [产品](product/product.md) | 定位、页面职责、核心使用路径与范围 |
| [逻辑与交互](product/logic-and-interactions.md) | 计时、打卡、统计、声音、提醒与外部动作 |
| [UI](product/ui-design.md) | 页面、图形、原生组件及可访问性 |
| [动效](product/motion.md) | 事件、过程、中断、表盘手感与减少动态效果 |

## 开发与工程

| 文档 | 职责 |
| --- | --- |
| [开发环境](engineering/development-environment.md) | 本地与 CI 工具链、安装、换设备、版本升级 |
| [Android 构建与发布](engineering/android-build.md) | 手动打包、正式签名、Secrets、蒲公英、产物与故障处理 |
| [架构](engineering/architecture.md) | 分层、依赖与模块公开 API |
| [状态管理](engineering/state-management.md) | Provider、草稿、命令、异步与反馈 |
| [运行时](engineering/runtime.md) | 时间、生命周期、音频、通知与性能 |
| [存储](engineering/storage.md) | AppPrefs、快照格式、错误、重试与重置 |
| [组件](engineering/components.md) | 通用 UI、弹层及交互约束 |
| [主题](engineering/theme.md) | TS、设计量、插值及适配 |
| [资源](engineering/assets.md) | 图片、声音、品牌图标及生成入口 |
| [路由](engineering/routing.md) | 页面栈、面板、返回及外部目标 |
| [原生组件与实时活动](engineering/system-surfaces.md) | 平台能力、展示协议、外部命令与降级 |
| [测试](engineering/testing.md) | 工程检查、长期回归、原生存储及性能采样 |

## 协作与当前问题

[工作流](workflow.md) 维护任务、Git 授权及文档规则；[已知缺口](known-gaps.md) 列出具体问题和测量边界。产品和工程规则由对应主文档维护，必要的设计理由随规则说明。

## 专项入口

仅在用户明确要求原型迁移、固定证据核对或 DS 同步时使用 [ProtoBridge 专项](integrations/proto-bridge.md)；日常 Flutter 迭代不进入该流程。
