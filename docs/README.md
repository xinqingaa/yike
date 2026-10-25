# 一刻文档

当前以 Flutter 独立迭代为主。先读 [工作流](workflow.md) 与 [已知缺口](known-gaps.md)，再按任务阅读；普通开发不读取原型/Vue 源码或调用 ProtoBridge MCP。产品介绍与运行方式见 [根 README](../README.md)。

## 产品与体验

| 文档 | 职责 |
| --- | --- |
| [产品](product/product.md) | 定位、范围、页面职责与核心路径 |
| [逻辑与交互](product/logic-and-interactions.md) | 状态机、数据事实、保存恢复、统计与动作结果 |
| [UI](product/ui-design.md) | 页面结构、滚动、三主题、布局与可访问性 |
| [动效](product/motion.md) | 触发、过程、事件身份、中断、重播与减少动态效果 |

## 工程规范

| 文档 | 职责 |
| --- | --- |
| [架构](engineering/architecture.md) | 分层、依赖、模块公开 API 与功能落点 |
| [状态管理](engineering/state-management.md) | Riverpod、草稿、控制器、异步与一次性反馈 |
| [运行时](engineering/runtime.md) | 生命周期、时间、可见性、资源与性能 |
| [存储](engineering/storage.md) | AppPrefs、快照、错误、重试与版本 |
| [组件](engineering/components.md) | 公开 UI、弹层、扩展准则与受控语义 |
| [主题](engineering/theme.md) | TS、类型化设计量、插值与视口适配 |
| [资源](engineering/assets.md) | 导入资源与 Flutter 自有资源的维护 |
| [路由](engineering/routing.md) | 根导航、页面栈、面板、返回与参数 |
| [测试](engineering/testing.md) | 独立客户端检查、行为、原生、动效与 profile |

## 协作与状态

[工作流](workflow.md) 维护阅读、授权与交付要求。[已知缺口](known-gaps.md) 只维护当前未解决项及验证边界。产品规则变更随仓库版本维护。

## 决策记录

- [Flutter 独立迭代](decisions/2026-10-23-flutter-development.md)
- [动效事件与重播](decisions/2026-10-23-motion-policy.md)
- [秒级时长与统一有效范围](decisions/2026-10-24-duration-rules.md)
- [三模式并行与前后台提醒](decisions/2026-10-24-parallel-timers-notifications.md)
- [Apple 研究与页面精修最终指令](decisions/2026-10-23-page-refinement.md)

决策记录说明日期、已决定的行为和原因；具体规格仍在所属产品/工程文档维护。

- [记圈与回顾统计联合实施](decisions/2026-10-24-laps-review.md)

[六阶段计划](plan/README.md) 记录实施范围：第一至四阶段已完成并获用户验收。第一、二阶段验收后的常用项、设置入口与试听已合入；第三、四阶段的临时验收脚本、专用截图与交接说明已清理。第五阶段已接入并行计时、状态条、当前模式反馈及习惯前后台提醒，2026-10-25 已获用户功能与逻辑验收，临时材料已清理，UI 优化计划待确认；第六阶段汇总展示、优先级、暂停保留和外部操作也已确认，原生接入未启动。

[Apple 研究与页面精修最终指令](decisions/2026-10-23-page-refinement.md) 记录研究与用户接管后的最终修改范围；当前工作区已按该指令修订，用户要求不运行测试，尚无修订后验收结论。[前轮复审提案](reviews/2026-10-23-motion-audit-and-polish-proposal.md) 只保留研究背景，不作为当前实施规格。

[动效与布局连续性实施记录](reviews/2026-10-23-motion-implementation.md) 记录六批代码接入、工程检查、iOS 原生过程和待测边界；[原实施计划](reviews/2026-10-23-motion-implementation-plan.md) 保留批准范围与验收矩阵。

## 历史评审

- [首次页面交付](reviews/2026-10-22-layer-1.md)
- [布局、主题与交互修复](reviews/2026-10-22-repair.md)
- [弹层自查](reviews/2026-10-22-popup-audit.md)
- [本地业务自检](reviews/2026-10-22-layer-2.md)
- [Flutter 体验修复](reviews/2026-10-23-flutter-experience.md)
- [布局与交互精修](reviews/2026-10-23-layout-polish.md)

历史结论保留当时的范围，不自动成为当前全量验收。原型迁移、固定证据与外部 DS 工作仅在用户明确要求时读取 [ProtoBridge 专项](integrations/proto-bridge.md)。
