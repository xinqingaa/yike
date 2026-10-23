# 文档整理与动效交接

记录日期：2026-10-23。用户要求本对话完成文档收尾，后续动效在新对话继续；已写的动效代码保留。本记录区分目标规格、已有初稿和验证结果，不表示动效已完成。

## 文档调整

首轮 Demo 到 Flutter 的迁移已获认可，README 与工作流明确当前以 Flutter 为主要开发对象。产品、交互、UI、动效和工程规范在本仓库维护；普通开发不读取原型、Vue 源码或调用 ProtoBridge MCP。不确定的工程细节自主判断并验证，尚无决定的产品取舍直接与用户讨论。

文档按一层目录分为 `product/`、`engineering/`、`integrations/`、`decisions/` 与既有 `reviews/`。架构重新明确模块依赖和分层，新增 [状态管理](../engineering/state-management.md)、[运行时](../engineering/runtime.md)、[存储](../engineering/storage.md)；组件、主题、资源、路由与测试规范同步补齐。完整入口见 [文档索引](../README.md)。

三个 ProtoBridge Skill 改为仅用户明确要求时触发，普通 Flutter 动效、主题或组件修改不会自动启动迁移/同步。专项需要的 Target 侧约束在 [本地专项协议](../integrations/proto-bridge.md#本地专项协议) 维护，不要求先阅读外仓说明文档。默认客户端检查已去除外部 DS 校验依赖，保留两个显式 DS 专项命令。

已移除直指相邻 proto-bridge 仓库的文档链接及历史本机截图链接；后者改为指向仓库内原 receipt 的追溯说明。历史 receipt 和其它原始附件路径文字保留，不伪称当前可访问。文档检查覆盖所有非生成 Markdown，核对链接、锚点、绝对路径与仓库边界，包括目标恰好在本机存在的越界链接。当前 Markdown 无需外链。

## 已批准的动效规则

[动效规格](../product/motion.md) 是目标行为，具体决定见 [动效事件与重播](../decisions/2026-10-23-motion-policy.md)。完成仅在事件发生且专注页可见时播放一次；不可见时完成，返回不补播。每次新的有效打卡可反馈，撤销后重新打卡可再反馈；历史读取、返回、普通重建和保存重试不播放。

首批只加克制的视觉反馈，不扩大触觉、音频或系统通知范围。动画不控制业务结算或保存；保存失败保留已接受的内存结果及明确未保存反馈。异常终止后的保存精度与恢复规则保持原状。

## 保留的代码初稿

以下均已写入工作区，尚未完成动效行为验收：

| 文件 | 当前初稿 |
| --- | --- |
| [motion_activity.dart](../../lib/common/motion/motion_activity.dart) | 路由、前后台与面板可见性的 MotionVisibility/MotionGate，组合 TickerMode |
| [app.dart](../../lib/app/app.dart)、[home_page.dart](../../lib/features/home/pages/home_page.dart)、[tab_view.dart](../../lib/common/widgets/navigation/tab_view.dart) | 注册动效 RouteObserver，根页面与保活 Tab 接入可见性控制 |
| [focus_projection.dart](../../lib/features/focus/logic/focus_projection.dart) | 只读时间投影，从会话锚点计算连续进度，不承担结算和保存 |
| [focus_dial.dart](../../lib/features/focus/widgets/focus_dial.dart)、[focus_page.dart](../../lib/features/focus/pages/focus_page.dart) | 局部绘制 Ticker、轻秒/分钟反馈、完成收束初稿，专注页接入 |
| [rolling_digits.dart](../../lib/common/motion/rolling_digits.dart)、[dial.dart](../../lib/common/widgets/yike/dial.dart) | 相邻秒变化位翻动、水下反色读数共用相位、波纹与日影明暗初稿 |
| [yike_motion.dart](../../lib/theme/yike_motion.dart) | Flutter 自有的幅度、比例与节拍窗口；时长仍读取 TS.motion |

没有修改 FocusEngine 的记账、结算、幂等与检查点规则；没有增加业务逐帧写入或新依赖。参数与视觉幅度仍需运行调整，不能因为存在 Controller 就判定符合产品意图。

## 后续批次与验证顺序

| 批次 | 目前状态 | 新对话接续 |
| --- | --- | --- |
| 文档与工作流 | 已整理；验证见下文 | 按本仓库入口阅读，不重新调取原型 |
| 专注基础与机械表盘 | 初稿已接入，未做行为/原生验证 | 先核对投影、数字、暂停/继续、完成与可见性，再调整机械过程 |
| 水位、日影与打卡 | 两表盘有部分初稿；打卡动效未开始 | 验证水下同步裁切与静止策略，落实三主题打卡及撤销/失败重试反馈 |
| 回顾、计圈与习惯列表 | 新动效未开始 | 实现翻期/周月衔接、日期明细、局部计圈插入与稳定身份列表更新 |
| 原生过程与性能 | 本轮未运行 | 三主题、正常/减少动态效果过程；具备设备条件时做真机 profile |

先阅读本记录、动效规格与工作区 diff，保留现有初稿并核对真实调用，不重新从零搭建。新增的持续 Ticker 会影响旧测试中的 `pumpAndSettle`：运行状态的测试应用有界 pump，并明确要验证的时间点；不要通过全局禁用动效掩盖过程问题。

必须补测 00:59/01:00、59:59/1:00:00、正计时整小时与长时长、倒数到零、暂停继续、再计和阶段切换；覆盖路由/根 Tab/应用隐藏、恢复时不补播、换主题、动态效果偏好变化、保存失败重试与快速撤销重做。检查水下副本的位置、颜色和翻数相位，读数语义仅暴露一次；关注现有 Widget 测试对完整数字 Text、文案数量和布局尺寸的依赖。

业务完成和视觉到零可能处于不同的校准帧：业务状态以 FocusEngine 为准，完成反馈不能被每帧投影重复触发。需通过测试核对所有可见性条件、Ticker 的创建与释放和初始完成态不播放。不要把实现意图写成已验证结论。

## 本轮验证

本轮已通过：

- `node tool/check-docs.mjs`：34 份 Markdown、175 个链接，外链为 0；目标文件、锚点和仓库边界通过。
- 文档检查器的 10 个隔离场景：包含相邻目录实际存在、绝对路径、符号链接越界、引用式/HTML 链接、错误锚点、GitHub 分支与固定提交的区别。
- 三个本地 ProtoBridge Skill 的 `quick_validate.py` 校验；使用临时 uv 依赖环境提供 PyYAML，未增加项目依赖。
- `dart format --output=none --set-exit-if-changed lib test integration_test`：151 个文件，无格式改动。
- `flutter analyze --no-pub`：无问题。保留初稿的收尾只修正弃用 TickerMode 读取与缺失花括号，未继续增加动效行为。
- `flutter test --no-pub test/proto_bridge_mapping_test.dart`：15 项本地映射/公共组件测试通过，不访问外部 Producer。
- 两个检查脚本的 Node 语法检查及 `git diff --check` 通过。

尚未新增动效专项测试，未运行完整 `verify.mjs`、完整 Flutter 测试、原生过程采集或 profile；以上静态与局部测试通过不代表动效已验收。历史 156 项测试及模拟器截图不作为这份初稿的验证结果。
