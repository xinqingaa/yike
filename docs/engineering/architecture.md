# 工程架构

一刻采用按 feature 组织的 Flutter 客户端架构，Riverpod 管理业务与页面状态，AppPrefs 隔离本地存储。专注、习惯和回顾各自拥有业务规则，应用层负责组合；抽象应解决实际职责、复用或测试问题。

## 目录与依赖

```text
lib/
  app/          应用组合、启动、根导航与跨模块协调
  router/       路由身份、注册与页面栈
  theme/        类型化设计量、主题组合、资源映射与插值
  storage/      AppPrefs、Codec 基类与 MMKV 平台适配
  common/       通用能力、组件、弹层与局部呈现机制
  features/     业务模型、规则、命令、页面与私有组件
```

`app` 是组合入口，可依赖 feature 公开 API 和基础能力。feature 依赖 common、theme、router 与 storage 的公开边界；router 仅在注册表导入页面。common、theme、storage 不反向依赖 feature，theme 只通过 storage 保存外观偏好。feature 不直接使用 MMKV，不导入另一个 feature 的私有页面、Widget 或 Provider 实现。

模块默认包含 `pages/`、`models/`、`providers/`、`widgets/`；复杂纯规则放 `logic/`。简单模块可保持少量文件，不为了目录形式创建空层。公开 barrel 只导出其它模块需要的接口，模型/规则入口与页面入口分开，避免模型消费方间接依赖页面。

## 分层职责

| 层 | 拥有什么 | 边界 |
| --- | --- | --- |
| 页面与 Widget | 布局、语义、焦点、输入控制器、动画与简单导航 | 发出业务意图，不直接序列化、写存储或结算记录 |
| 展示 Provider | 页面选择、草稿、校验、派生展示、动作协调 | 复用同一事实源，缩小订阅范围，清晰表达失败 |
| 模型与纯规则 | 会话状态机、校验、身份关系、统计口径 | 不依赖 Widget、BuildContext、存储或动画完成回调 |
| 数据协调与适配 | 初始化、快照组合、读取、写入、恢复与重试 | 不决定按钮外观、动画或页面构图 |

业务命令先校验身份与状态，再应用纯规则，提交同一份业务事实并尝试保存。消费方通过派生查询读取结果。内存生效与保存成功分开表达，保存重试不重复执行命令。

例如“暂停”：页面发出 pause → FocusActions 读取时间 → FocusEngine 冻结有效用时 → LocalDataController 提交快照 → 展示投影更新读数和操作 → 保存失败由应用边界显示未保存及重试。动画只呈现结果，不在动画结束后才暂停或落盘。

## 一刻模块划分

| 模块 | 职责 | 公开入口 |
| --- | --- | --- |
| focus | 会话模型、计时规则、偏好、专注历史与页面 | `focus.dart`、`focus_models.dart` |
| habits | 习惯模型、打卡、详情、编辑与管理 | `habits.dart`、`habit_models.dart` |
| local_data | 组合快照、初始化、提交、读取保护与重试 | `local_data.dart` |
| review | 消费专注和习惯事实，维护周期浏览 | `review.dart` |
| settings | 经公开 API 修改配置 | 设置命名路由 |
| home | 组合三个根页面 | 根命名路由 |
| onboarding | 单页新手介绍与表盘选择 | `onboarding.dart` |

`LocalDataController` 拥有组合业务快照；计时规则留在 FocusEngine，习惯规则留在 habits，统计由记录派生。UI、动效与 feature 规则分别由各自模块维护。只有出现独立数据源、明显性能问题或职责冲突时，再评估拆分 Repository/协调器。

## 状态管理

业务事实、页面选择与草稿使用 Riverpod；Provider、控制器、一次性反馈和重建规则统一见 [状态管理](state-management.md)。动画由生命周期内的 Flutter Controller/Ticker 驱动，逐帧进度不提升为业务 Provider。

跨页事实只维护一份。展示缓存不能成为第二套统计；修改名称不更换身份；副作用不由 build、派生 getter 或每帧回调执行。异步操作离开页面后不得使用失效 context 或覆盖新的草稿。

## 组件、设计与适配

先检查公开组件与真实构造函数。已有组件语义适用时扩展其受控 API，业务特有组合留在 feature。跨 feature 复用且职责稳定的 UI 才进入 common；时间、身份和生命周期等基础能力可按明确职责独立放入 common。

设计量从 TS 与本地类型化主题扩展点读取；布局用约束表达，不以固定手机坐标拼整页。系统文字缩放、触控目标、安全区与键盘规则见 [组件](components.md) 和 [主题](theme.md)。导入的生成产物与 Flutter 自有设计的维护边界见 [资源](assets.md)。

## 本地存储

只通过 AppPrefs 访问 MMKV，业务快照由 local_data 组合。键白名单、Codec、错误、版本、恢复与重置规则统一在 [存储](storage.md)。新的 key 先更新该文档，再修改类型化注册。时间和前后台策略见 [运行时](runtime.md)。

## 新增与修改功能

先明确用户动作、事实变化、失败结果及可观察行为，再选择所属 feature 和复用接口。栈级页面更新路由常量、注册与参数解析；面板和页面内模式使用各自导航边界。以相关纯规则、Provider、Widget 或原生测试验证用户行为。

新增依赖前检查 Flutter SDK、现有能力与包的公开 API；说明引入目的、平台支持和生命周期，不用新包复制已有基础设施。依赖变更同步更新 `pubspec.yaml` 与锁文件，生成目录不提交。构建与检查方式见 [测试](testing.md)。

产品取舍和跨模块边界的规则及必要理由直接写入所属主文档，与代码共同维护。

## 声音与震动

`common/feedback` 拥有类型化 cue、独立播放器接口及可替换的反馈服务，不依赖 feature。`app/feedback_boundary.dart` 在业务数据可读取后组合偏好与前后台状态，并预加载音效。focus 的纯 `focus_beats` 计算节拍边界，应用级 `focusFeedbackProvider` 消费 250ms 时钟与既有完成事件；FocusActions 与 HabitsPresentation 只在有效操作被接受时发出反馈。FeedbackService 只维护总开关及通用 scope → FeedbackOptions 映射，不认识 feature；事件携带来源 scope，声音句柄按来源记录以支持局部停止。模式与打卡各自持有配置，总开关不改写局部值。反馈错误不传播到业务命令，结束或后台不补播。服务仅处理来源配置与应用生命周期，视觉可见性由 MotionGate 管理。

应用 / focus 协调层组合路由、根 Tab、所选模式与弹层用途，决定允许计时反馈的来源；通用反馈服务不依赖业务页面。本模式计圈面板允许反馈，通用模态静默，状态条在所有模态期间隐藏。声触门控和视觉 MotionGate 各自处理对应条件，状态条消费 feature 公开投影，系统适配不依赖 feature。具体规则见 [运行时](runtime.md#计时反馈可见性规则)。

表盘纯映射、吸附与阻尼规则位于 focus/logic，输入与局部 Ticker 位于 focus/widgets；FocusActions 只接受合法最终时长，FocusEngine / FocusProjection 共享 3599 秒上限。设置编辑通过类型化路由参数自动展开既有面板，feature 不跨导入私有页面。分类试听由通用服务提供声音专用 API，页面不直接操作音频引擎。

## 回顾与统计

`review/models/review_period.dart` 表达周期与可选类型，回顾 Provider 与统计实例分别拥有选择。`review/logic/review_statistics.dart` 的纯查询消费 focus 公开的同一日期分片与会话身份；原始开始小时从分片 view 的 time 读取，统计不维护独立事实源。圈面板复用 FocusActions、FocusSession 与既有秒级投影，装饰控制器只在面板实例存在。

FeedbackService.select 的可选 scope 支持只受总开关控制的回顾查看与沿用 habits 局部门控的习惯查看；不创建 review 偏好、不绕过服务调用系统触感。AppDataCard、ChartValue 与 CommonYearGrid 的公开职责见 [组件](components.md#数据卡与统计组件)。

习惯详情与统计习惯完成格共用 habits 公开的 `HabitDayTarget` 与 `habitDayColor`；习惯状态、完成时间、当周进度与局部触感门控由同一组件提供，review 不复制该卡规则。习惯详情的年格布局使用 `CommonYearGrid`，不自建滚动和星期月份排布。

## 通知与应用级状态区域

`common/notifications` 定义类型化目标、请求、权限、可替换适配器与调度元数据；不依赖 feature。`app/notifications/notification_plan.dart` 消费公开事实，输出三路计时和按日期全局排序的最多 60 个习惯请求；`notification_coordinator.dart` 串行对账、代次失效、保存截止占位、前台到点合并、权限和安全导航。原生成功与业务保存分开报告，设置页通知入口位于“通用”。

Android 使用最小 MethodChannel / AlarmManager 接收桥：发布前读取原生前后台状态；一次性预约落在独立原生调度缓存，重启 / 升级 / 时区变化重建，前台跳过系统通知。缓存不包含会话或打卡快照，不承担业务结算。iOS 使用 flutter_local_notifications 22.3.2 / UNUserNotificationCenter，前台展示选项全部关闭；单项取消 pending 与清理 delivered 分开。设备时区来自 flutter_timezone 5.1.1，timezone 0.11.2 提供日历换算；时区不可读时显示故障，不假定 UTC 成功。

`TimerStatusBoundary` 唯一持有顶部玻璃区域、行身份和展示寿命；只消费公开投影，不做结算。正文使用原始 MediaQuery，不增加安全区或改 Navigator 约束；浮层测量只供未保存提示错开。行内按秒订阅，独立 CustomPainter 从公开 FocusProjection 在帧内投影进度；光效控制器只驱动绘制，不写业务状态。应用根部的私有 Overlay 为 Navigator 外的图标 Tooltip 提供宿主；未保存提示仍为独立浮层身份。模态不依赖库 pause / resume，宿主自身负责淡出、收展及触摸 / 焦点 / 语义屏蔽。减少动态效果绕过尺寸补间，后台停止装饰 Ticker。应用导航前由 AppDataCard.closeAll 关闭只读查看卡，通知点击等待读取成功和最后一层模态真实退场。

## 原生桌面组件与实时活动

`common/system_surfaces` 定义版本化展示 DTO、严格外部意图、类型化展示元数据与可替换 MethodChannel 适配器，不依赖 feature。`app/system_surfaces` 消费 focus / local_data 公开事实及主题，派生三模式、今日已记录时长和习惯进度，串行发布、失败重试及重置屏障由同一协调器负责；读取阻断分支也启动该协调器以撤销旧展示。

Swift WidgetKit / ActivityKit 与 Kotlin RemoteViews 只读取原子展示缓存，不读取 MMKV 或独立结算。外部动作通过 URL / PendingIntent 打开主应用，校准后验证代次、会话、阶段、预期状态及状态转换 token，保存消费回执后调用 `FocusActions.commandResult`。状态 token 只保留在本进程，旧进程按钮只定位应用并提示状态更新。命令是否接受、业务是否保存及原生展示是否成功分别表达。

`app/external_targets.dart` 统一通知与组件的查看目标，延迟跨越读取阻断、导航就绪及模态草稿；命令消费不等待导航。平台适配只消费投影与统一命令，协议和验证要求见 [原生组件与实时活动](system-surfaces.md)。
