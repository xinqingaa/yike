# 技术方案

状态：方案稿。返回 [计划索引](README.md)。架构边界沿用 [工程架构](../engineering/architecture.md)，存储规则沿用 [本地存储](../engineering/storage.md)。

## 依赖

| 依赖 | 版本 | 用途 | 说明 |
| --- | --- | --- | --- |
| flutter_soloud | 5.2.1（固定） | 预加载的短音效，低延迟、可以同时播放多个 | iOS 最低版本要求 13，当前工程是 15，满足 |
| audio_session | 0.2.4（固定） | 把 iOS 音频会话设为 ambient 并与其它音频混音 | flutter_soloud 本身不管理系统音频会话 |
| flutter_local_notifications | 22.3.2（固定） | 阶段 5 的后台到点通知和习惯提醒 | 阶段 5 开始前不加入 |
| HapticFeedback | Flutter 内置 | 震动 | 不需要额外依赖或权限 |

不加入 audioplayers，它的延迟不适合每秒和拨动的反馈。不加入图表库，统计图形按现有做法用 CustomPainter 实现，以便适配三主题的笔触。

iOS 不开启后台音频模式（UIBackgroundModes audio），应用进入后台后不再播放节拍；后台的到点提醒由通知负责。

## 模块落点

```text
lib/common/feedback/
  feedback_service.dart     对外接口：play(FeedbackCue)，按偏好分发到声音和震动
  sound_player.dart         封装 flutter_soloud 与 audio_session，可在测试中替换
  haptic_player.dart        封装 HapticFeedback，可在测试中替换
  feedback_cue.dart         事件枚举：tick、chime、finish、light、select、limit……
lib/features/focus/
  logic/focus_beats.dart    纯函数：根据会话的有效时间与偏好，计算两次采样之间越过了哪些节拍边界
  providers/focus_feedback.dart  监听会话转换与时钟脉冲，发出节拍和完成反馈
  providers/dial_adjust.dart     本次时长（只在内存中），提交和清除
  widgets/dial_adjuster.dart     手势、惯性、吸附与回弹，包裹 FocusDial
  widgets/lap_badge.dart         侧边挂件与抛物线飞入
  widgets/lap_sheet.dart         右侧记圈面板
lib/features/review/
  logic/review_stats.dart        纯计算：周期汇总、趋势、类型占比、时段、习惯完成、年度分档
  pages/stats_page.dart          统计页
  widgets/stats_*.dart           各图形
  widgets/day_peek.dart          长按数据卡内容
lib/common/overlay/
  app_pop.dart                   新增 AppPop.menu(anchor, builder)，Sheet 新增 direction 参数
asset/yike/sound/                9 段音效：{mechanical|water|sundial}-{tick|chime|finish}.wav
tool/synth-sounds.mjs            合成首版音效的脚本（Node，无第三方依赖）
```

common/feedback 不依赖任何 feature。主题音色通过 `TS.pack.id` 选择，由调用方在发出事件时带上主题。

## 反馈的时间来源

- 节拍：focus_feedback 监听现有的 250ms 时钟脉冲，每次用 FocusProjection 计算当前有效秒数，与上一次采样比较，由 focus_beats 返回这一段越过的边界（倒计时的每一秒、最后 10 秒、间隔分钟）。两次采样之间越过多个边界时只播放最后一个，避免一次补播一串。
- 进入后台、页面重建、会话 id 或阶段变化、暂停时，重置上一次采样，不补播。
- 完成：沿用现有的 focusCompletionEventsProvider。声音和震动不再要求专注页可见，只要求应用在前台；视觉收束的可见性门控保持不变。
- 打卡、计圈、开始和暂停：在发出业务命令的位置直接调用 FeedbackService，与业务成功与否无关（命令被拒绝时，例如重复计圈，不发反馈）。

250ms 的脉冲意味着每秒滴答可能有最多 250ms 的相位误差，但节奏仍然是每秒一次。如果真机上听起来不均匀，再给 focus_feedback 单独加一个对齐到整秒的计时器，这不影响业务计时。

## 数据模型

### 偏好

TimingPreferences 新增三个字段，随业务快照保存：

| 字段 | 类型 | 默认 |
| --- | --- | --- |
| haptics | bool | true |
| secondTick | bool | true |
| beatMinutes | int，取值 0、1、5、10、15 | 5 |

快照目前只接受 schemaVersion 1，并且存储规范写明了“无需兼容旧实例”。这三个字段读取时如果不存在就使用默认值，所以不需要提高版本号；写出时总是写全。这一点会在存储文档中注明。

### 本次时长

FocusData 新增只在内存中的 `pomodoroOnce`（秒，可空），不写入快照：

- FocusEngine.start 在番茄专注阶段优先使用 pomodoroOnce，然后清空它。
- 修改设置中的专注时长时清空它。
- 倒计时的本次时长直接复用已有的 `countdown` 字段，拨动和快捷项修改的是同一个值。

FocusViewData 在待开始时读取 pomodoroOnce，所以读数、表盘和“开始专注”按钮使用相同的值。

### 统计

review_stats 只接收 FocusRecordView 与 HabitViewData 两个列表，输出不可变的结果对象，不依赖 Widget。时段分布使用记录的开始时间。统计页与回顾页都通过它计算，回顾页现有的汇总逻辑改为调用这里的函数，保证口径一致。

类型筛选状态放在 ReviewSelection 中（新增 mode 字段，可空），回顾页与统计页各自持有一份选择，进入统计页时从回顾页复制。

## 关键实现

### 表盘手势

- 使用 RawGestureDetector 和一个在按下时立即胜出的自定义识别器，只在表盘可以拨动时启用；其它状态不注册，页面滚动不受影响。
- 角度映射使用 atan2 求出相邻两次采样的角度差，规范到 (-π, π] 后累加，所以经过 12 点时不会跳变。水位主题使用竖直位移除以杯身高度。
- 惯性使用 FrictionSimulation，速度降到阈值以下后换成 SpringSimulation 吸附到目标分钟。越界部分按 1/(1+x) 的阻尼缩小。
- 拨动过程中的数值只存在 Widget 的 ValueNotifier 中，驱动 DialFrame 与读数；吸附结束后才调用 FocusActions 提交一次。
- 文字减弱通过一个页面级的 ValueNotifier<bool> 下发，FocusPage 用 AnimatedOpacity 包裹相应区域。

### 记圈挂件与飞入

- 挂件与飞入标记都在 FocusPage 内部的 Overlay 层（OverlayPortal）中绘制，与页面同生命周期，不使用全局弹层。飞行的起点取被挤出那一行的全局位置，终点取挂件的全局位置。
- 抛物线：x 随时间线性变化，y = 线性插值 − h·4t(1−t)，h 取两点距离的 35%。
- 右侧面板使用 Pop.sheet，direction 为 right。现有的 AppPop.sheet 只支持底部，这里给 SheetPopup 增加 direction 参数，并设置 slideLeft 方向的入场动画；面板的内容是独立的 ConsumerWidget，直接监听 focusViewProvider，所以与专注页的状态保持一致。

### 数据卡

AppPop.menu 封装 Pop.menu：传入 PopupAnchorController 和 builder，使用当前主题的弹层表面样式，遮罩为透明、拖动即关闭。周柱、月历日期和热力图格子各自用 PopupAnchor 包裹；热力图因为是一整张 CustomPaint，改为在长按位置放一个临时的锚点矩形。

### 音频资源

tool/synth-sounds.mjs 用正弦波、噪声和指数衰减包络合成 16 位、44.1kHz、单声道的 WAV，每个文件小于 150KB。脚本输出到 asset/yike/sound/，生成的文件提交到仓库，并在 [资源规范](../engineering/assets.md) 中登记来源为“仓库内合成”。

## 测试

| 范围 | 测试 |
| --- | --- |
| focus_beats | 每秒、最后 10 秒、间隔分钟、第 0 分钟、跨越多个边界只播最后一个、暂停和恢复不补播 |
| FeedbackService | 使用替身播放器，检查开关、主题音色和限流（拨动不小于 40ms） |
| 本次时长 | 拨动后开始使用本次值、下一轮恢复默认、修改设置清除、运行中拒绝 |
| 表盘手势 | Widget 测试拖动：经过 12 点累加、越界回弹、惯性吸附到整分钟、慢速吸附到 5 分钟刻度 |
| 记圈 | 第 3/4 圈时挂件出现、计数正确、飞行标记数量上限、面板内计圈与专注页一致 |
| 统计 | review_stats 与回顾页数字一致；跨日记录、类型筛选、空期、日均分母 |
| 数据卡 | 长按弹出、未来日期不弹出、筛选说明 |

原生检查在 iOS 模拟器上进行：三主题 × 浅色和深色，听声音、看拖动与飞入的过程。震动只能在真机上确认，将列入已知缺口。

## 文档同步

每个阶段完成后同步：

- [动效规格](../product/motion.md)：拨动、惯性与吸附、记圈飞入、统计图形的生长与筛选过渡。
- [逻辑与交互](../product/logic-and-interactions.md)：本次时长、反馈事件、统计口径、新增偏好的初始值。
- [UI 设计](../product/ui-design.md)：删除“表盘不可拖动或点击设置时长”，补充统计页与记圈面板的结构。
- [产品说明](../product/product.md)：页面表增加统计页，更新提示音的范围说明。
- [本地存储](../engineering/storage.md)、[资源](../engineering/assets.md)、[架构](../engineering/architecture.md)、[路由](../engineering/routing.md)：新字段、音效资源、common/feedback、统计页路由。
- [已知缺口](../known-gaps.md)：移除“音频尚未接入”，加入真机震动和通知待验证。
- [文档索引](../README.md)：加入本目录的入口，把当前交接指向本计划。
