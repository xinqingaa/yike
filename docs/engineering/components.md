# 公共组件

一刻的公共组件按职责分类位于 `lib/common/widgets/{action,input,display,navigation,data,charts}/`，组合壳位于 `lib/common/widgets/composition/`，业务与测试统一从 `lib/common/widgets.dart` 导入。组件负责稳定的交互语义、尺寸和 Theme 映射；业务页面只传入数据、状态和回调。弹层统一走 `lib/common/overlay/app_pop.dart` 的 `AppPop`。

`AppPop` 保持独立弹层边界，不由 Widget barrel 隐式导出。`PbPageTransitions` 由 Theme 应用，页面不自行组合另一套栈转场。组件按 Flutter 真实职责扩展，导入基线的映射身份见文末说明。

## 组件职责

| 组件                               | 语义和适用场景                                                   |
| ---------------------------------- | ---------------------------------------------------------------- |
| `CommonAppBar`                     | 页面标题、返回和顶部操作；页面不要重复创建返回 AppBar            |
| `CommonCard`                       | 纯 surface 容器：背景、边框、圆角与可选抬升；业务结构由 child 组合 |
| `CommonFormSection`                | 表单字段的标题、描述、操作和字段分组；不是内容卡片               |
| `CommonBadge`                      | 只读状态或严重度标签；不承担选择交互                             |
| `CommonChip`                       | 轻量标签或可点击的短选项；不能代替状态 Badge                     |
| `CommonFilterBar`                  | 单值横向快捷筛选；不拥有高级筛选或视图区                         |
| `CommonDataList`                   | Flutter `ListView.builder/separated` 与列表 surface              |
| `CommonScrollableDataList`         | `pull_to_refresh_flutter3` 下拉刷新、加载更多与回弹约束           |
| `CommonSearchBar`                  | 搜索输入、提交、清除                                             |
| `CommonMenuField`                  | `AppPop.dropMenu` 的表单锚点；不是第二套菜单实现                 |
| `CommonTextField`                  | 单行文本输入；无标题时 recessed 填充                             |
| `CommonTextArea`                   | 多行文本输入；无标题时 recessed 填充                             |
| `CommonRadioGroup`                 | 互斥选项集合                                                     |
| `CommonCheckbox`                   | 独立勾选项                                                       |
| `CommonSwitch`                     | 二值开关设置；不能用 Checkbox 静默替代                           |
| `CommonButton`                     | 主要、次要、描边、强调、危险、轻量六种动作；页面不配色槽                     |
| `CommonIconButton`                 | 单图标动作（含 loading）；必须提供 tooltip                       |
| `PbPageTransitions`                | 栈级页面转场；默认 iOS 侧滑，可选 Android zoom                   |
| `CommonPrimaryTabs`                | 玻璃轨道 + 官方 TabBar indicator 连续定位的选中面 |
| `CommonSecondaryTabs`              | 官方 TabBar + 从文字行盒定位的 10×5 caret 指示器                 |
| `CommonTabView`                    | 官方 TabBarView 内容切换、页面保活与 swipe 所有权                           |
| `CommonEmptyState`                 | 空数据或未配置状态                                               |
| `CommonSpinner` / `CommonProgress` | 加载指示和进度展示                                               |
| `CommonDivider`                    | 语义分隔线                                                       |
| `CommonAvatar`                     | 人员或主体头像/首字母                                            |
| `CommonBottomNav`                  | 2–5 个顶级页面目的地；固定 icon + label、无顶部指示条            |
| `CommonIcon`                       | 项目登记的图标、尺寸、tone 和装饰/无障碍语义                |

## 扩展组件

| API | 职责 |
| --- | --- |
| `CommonStepper` | 有界数值输入；按钮、键盘与文本统一回调 |
| `CommonWheelPicker` | 1–3 列独立滚轮；数字自身在列内居中、单位紧邻右侧，窄列等比缩放，外部状态可更新 |
| `CommonRingProgress` / `CommonMetric` / `CommonTag` | 自绘环形进度、指标数值与只读标签 |
| `CommonMiniBars` | 自绘柱状趋势；保留原始读数语义，长序列横向滚动 |
| `CommonHeatmap` | 把日期整理成周，并承载标签、语义和调用方提供的年格 |
| `CommonMonthCalendar` | 显式 month/today、UTC 日期、禁用日与自定义日单元；不读取系统日期 |
| `CommonListCell` / `CommonGroupedList` | Row 样式列表单元与稳定分组；使用外层滚动 |
| `CommonBrandMark` | 品牌资源/Widget 槽位，缺资源时名称兜底 |
| `CommonLaunchScreen` | Flutter 欢迎页或静态启动页；导航与忙碌状态由调用者控制 |
| `CommonGlassSurface` | unified_popups 的玻璃容器，支持高对比度/显式实色降级 |

`CommonDecisionActions` 统一单个主要按钮或左次要、右主要按钮；`CommonFlowSheetContent` 提供独立滚动正文与固定页脚。步骤指示默认关闭，仅传入 `progress: CommonFlowSheetProgress(step: ..., total: ...)` 时占位和显示；普通编辑分支不传 progress。这些是 Flutter 组合辅助。图表和日历不创建第二套状态或弹层。`CommonPressableSurface` 使用主题强调色与 pressed Token，在子内容上方绘制短暂按压反馈；支持主题形状与键盘焦点，供不透明图形及选项使用。回顾月历不传 value，不保留日期选择语义；通用月历传 value 时仍支持受控选择。

## AppPop 弹层

| 方法                                     | 对齐                    |
| ---------------------------------------- | ----------------------- |
| `toast`                                   | SnackbarToast 纯文本提示 |
| `confirm`                                | DialogPanel             |
| `sheet`                                  | BottomSheet             |
| `flowSheet`                              | FlowSheet（多步页面栈） |
| `loading` / `hideLoading` / `runLoading` | 全局阻塞 Loading        |
| `dropMenu`                               | 有限选项锚定菜单        |
| `actionSheet`                            | Sheet 内的受控动作列表   |

业务代码只调 `AppPop` 或 `AppSheet`，不直接调 `Pop`。公开方法不接收调用处 `BuildContext`；封装用已挂载导航器上的主题解析 Token 与材质。页面把正文做成 `child`。需要从按钮带回结果时，先建 `AppSheet<T>`，用 `sheet.show(child: ...)` 打开，用 `sheet.complete` 或 `sheet.dismiss` 结束。只展示、靠标题栏关闭的面板用 `AppPop.sheet(child: ...)`。

`CommonGlassSurface` 组合使用 unified_popups 的 LiquidGlass；明确轮廓，提供清透和实色降级。`AppPop.actionSheet` 是 Sheet 内的动作列表组合。`app_pop.dart` 只维护公开调用边界，内部实现按 `toast.dart`、`confirm.dart`、`sheet.dart`、`flow_sheet.dart`、`loading.dart`、`menu.dart` 分工；`popup_theme.dart` 负责材质与外壳，`sheet_header.dart` 负责紧凑头部。库的 builder 与 `PopupHandle` 留在这一层。

`SheetStyle` 统一提供左右 md 留白，正文不得再次添加同一层左右 Padding。`AppSheetContent`（从 AppPop 导出）是可选的滚动正文与固定操作区，可按需启用分隔线；普通短内容直接用 `Column`。`CommonFlowSheetContent` 在同一外壳内提供步骤与固定页脚，默认不绘制分隔线。

Sheet 默认 `SheetSizeConfig()`，高度随内容，不超过屏幕。写入 `maxHeight` 或 `height` 会把面板撑到该比例；`SheetDimension.fraction(1)` 是接近全屏，只加在需要固定高面板的那一次调用上。

公共组件不保留旧构造参数或历史别名；feature 必须直接迁移到当前 API。

## 重要语义边界

- `CommonBadge` 是展示语义，`CommonChip` 可以有选择交互；两者不能按外观互换。
- `CommonFilterBar` 负责筛选布局和选中状态，不能用任意 `Wrap` 拼出等价实现。
- `CommonScrollableDataList` 负责刷新、加载更多和 footer，不能用普通 `ListView` 静默替代。
- `CommonFormSection` 负责表单分组，不等于带边框的 `CommonCard`。
- `CommonSwitch` 和 `CommonCheckbox` 的交互语义不同。
- `LiquidGlassDecoration` 是 `CommonPrimaryTabs` 的私有材质适配；位置、宽度、滚动与动画必须由官方 `TabBar.indicator` 管理。

## 受控交互契约

- `CommonFilterBar` 必须接收可写的选中状态，并通过完整回调更新页面状态；回调后可见内容必须反映筛选结果。
- `CommonSearchBar` 有查询语义时必须连接到当前可见列表或空态；不能只更新输入框文本。
- `CommonScrollableDataList` 的刷新必须更新可观察的加载或数据状态，并在完成后反馈结果。
- `CommonMenuField`、`CommonRadioGroup`、`CommonSwitch`、`CommonCheckbox` 和按钮不得提交空的 `onSelected`、`onChanged`、`onPressed` 或等价回调。
- 页面负责把组件状态接入业务模型；组件负责稳定的交互语义、尺寸和 Theme 映射。

## 参数和实现依据

- 先检查组件构造参数和相似页面，再决定视觉变体。
- 组件内部已有的尺寸、圆角、边框和颜色必须优先通过 `TS` 继承。
- 本地产品需要而公共组件参数不足时，按稳定职责扩展受控 API，并检查真实调用；不要在 feature 中复制公共实现。只有需要产品取舍时才提问。
- 组件用法以真实构造函数、公共组件测试和现有 feature 调用为准；一刻没有独立组件展示入口。

PrimaryTabs 本身只提供选择条，TabView 是可选的独立视口。局部范围或模式选择使用选择条和受控回调，不创建空 TabView。

## 尺寸与交互约定

`CommonPrimaryTabs.size` 支持 `md`（controlMd 轨道）和 `sm`（controlSm 轨道），选中面使用上下 xs 内缩。`CommonTabView` 持有真实的可滑动面板；受控业务确认由页面 Provider 协调。需要先确认再切换时，等宽 PrimaryTabs 使用 `onSelectionRequested`，该回调只发出请求，选中位置由调用者在确认后更新 controller；请求点击和键盘激活不提前推进 TabBar。

`CommonListCell` 导航行的标题、数值和留白共用整行 InkWell，箭头仅用于提示。普通文字行以 content 行高加上下 md 内边距布局，避免嵌套箭头按钮把行撑到 76px。开关行保留独立开关触摸范围，行背景点击也能切换；disabled 禁止两种入口。`CommonGroupedList` 标题与容器左边对齐，无额外卡片外边距，并裁剪整行反馈到容器圆角。

`AppPop.sheet` 与 `flowSheet` 显式传递 slideOffset=1，业务等待会在 dismissed 完成后返回，以便串联确认层时保留完整退场。

## Flutter 扩展与可访问性

跨 feature、职责稳定且存在真实调用才提升 common；业务文案、计时结算和打卡身份留在 feature。扩展时核对并同步迁移已有调用，完整处理 disabled、loading、焦点、键盘、语义与回调，默认值应有明确用途。组件不能假装执行成功，也不能用动画完成回调提交业务。

布局遵守父约束、安全区、文字缩放与最小触控目标，长文本允许换行或局部滚动。装饰层排除重复语义，读数只暴露一次可读标签。动效遵守可见性与减少动态效果，复用本地共享机制；普通 Flutter 扩展不由 Producer 能力或固定 Evidence 限制。组件改变后运行相关行为与布局测试。

## 导入基线与身份

目录分类不改变既有 componentId 或 role；精确映射由根目录 `proto-bridge.target.json` 维护，不能从外观描述推断。CommonFormSection 等本地组合壳不冒充导入组件，新增本地能力也不自动新增 Producer 身份。外部 Contract 的核对仅在用户明确要求的 [专项](../integrations/proto-bridge.md) 中执行，日常组件设计以本地产品和工程规则为准。

## 公共动效接入

`common/motion` 的 MotionContent、MotionSize、MotionExpand 与 MotionList 各自管理内容替换、尺寸、局部展开及身份差异。退场立即失去命中、焦点和语义；减少动态效果直接呈现当前内容并保留草稿/滚动。列表通过身份索引保持未变化行，不使用整组重新入场。

MotionPage 用于周期和日期明细的水平翻页，裁切新旧内容，不叠加淡化文字。MotionExpand 默认保持左对齐；CommonListCell 的数值受父约束限制，箭头固定在尾部，不与标题平分剩余宽度。表盘的文字度量和所有字形使用同一份已解析字体、粗体、方向、语言与缩放，静止和翻动共用槽位；缩放后的读数高度参与主题布局。水体裁切完整尺寸图层，不压缩杯形；状态文案独立于水下读数。

AppPop.status 封装统一库的完全自定义能力，SDK 句柄留在 overlay；应用边界拥有 AppStatusPopup 的寿命，feature 不持有底层句柄。AppPop 的模态打开和实际 dismissed 深度用于状态浮层优先级及背景一次性反馈的抑制。

模态深度由应用 ProviderScope 中的 popupActivityProvider 管理，不使用静态全局状态；未保存提示的展开选择也由实例 Provider 管理。

### 悬浮状态区域

使用单个应用级常驻展示宿主组合最多三行计时状态；任何 AppPop 模态打开时隐藏并禁止交互，最后一层真实退场后恢复，不改变计时。unified_popups 2.2.1 的 `PopupHandle.pause/resume` 及 Host `Offstage/IgnorePointer` 支持挂起时保留内部状态，本地 `AppStatusPopup.suspend` 封装该语义。

宿主可以保活，但完成条不能常驻：可见行自然完成后拉满 / 标记、短停留并自动退场；新行、行增减、悬浮外壳高度及模式转场须同步过渡，正文不参与避让。库 pause / resume 不包含这些动画，应在本地呈现层先完成受控淡出再挂起，交互在隐藏意图产生时立即关闭；恢复从最新运行 / 暂停集合呈现，不补播已错过的完成。持续时长与中断规则统一见 [动效规格](../product/motion.md#站内状态条)，不能用重复开关弹层替代连续过渡。

计时宿主使用应用 Stack，定位于原系统安全区下；测量仅供其它浮层错开，与 `AppStatusPopup.show` 的 `yike-unsaved` key 独立；未创建另一份同 key 浮层，SDK 句柄仍留 overlay。状态条只用玻璃、进度、行点击与一个暂停 / 继续，不创建三个独立 Toast。应用边界只协调计时与未保存两类浮层，正文不增加顶部 inset，feature 不拼独立 Overlay 或接管表单生命周期。

本模式计圈面板仍允许计时反馈，通用设置 / 编辑 / 确认层不允许；这与“所有模态期间状态条隐藏”是两条不同规则，模态深度不能独自承担反馈来源选择。详见 [前台反馈门控](../product/logic-and-interactions.md#声音与震动)。

## 数据卡与统计组件

`AppSheet.show` / `AppPop.sheet` 通过 direction 指定方向。记圈面板使用 right、全高、100% 屏宽，不设置额外 maxWidth；底部面板使用默认方向。共享封装管理安全区、头部、固定操作区、滑动、遮罩、返回、实际 dismissed 与模态深度。

`AppDataCard` 在 overlay 内封装 Pop.menu 和私有句柄；feature 通过 DataCardTarget 提供锚点、内容与操作。数据卡是非模态查看层，透明穿透滚动，用 TapRegion 处理外点关闭，页面在滚动/选择变化时关闭；路由、Tab 不可见与后台同样关闭。锚点摆放与避边由统一库处理，不另建几何算法。宽度用本地 dataCardWidth，默认 260，并支持缩放/插值。

`CommonPressableSurface` 支持可选 onLongPress；短按与长按使用同一主题反馈。`CommonMonthCalendar.dayInteractionBuilder` 将日期视觉与 FocusNode 一起交给调用方，在同一个 CommonPressableSurface 上处理点击与长按，避免嵌套命中区域；方向键与默认日期选择行为保持，不增加选中事实。CommonYearGrid 共用年度日期排布与横向滚动，习惯详情和最近一年专注都使用它。CommonHeatmap 提供周数据、标签和语义，格子由调用方组合。CommonHeatmapBlock 绘制无边框实色格。习惯年格的创建前、未来和周对齐占位用 heatmapOutside；专注年格的周对齐占位与零时长同一档主色。调用方决定格子是否响应。

日期查看统一使用 DataCardTarget，在同一 CommonPressableSurface 上将 onPressed/onLongPress 接到同一个 show；每日记录 Sheet 仅由专注日期卡中的明确入口打开；返回优先关闭当前 Menu，关闭后再返回来源页面。热力图默认与查看状态均使用无边框色块，键盘焦点使用公共按压组件的可访问性反馈。

## 状态条与通知组件

AppSheet 的受控 `timerPanel` 用途只表示仍可允许其计时来源反馈的面板，不改变模态深度；嵌套通用层仍静默。Toast 可传局部 duration，习惯静默提示使用 3 秒，其它提示沿用主题时长。MotionList 可接收 scrollToStartToken，仅在外部导航定位身份变化时回列表顶部，维持行状态。AppDataCard.closeAll 由应用跳转边界使用，不把非模态查看卡当作模态。

`AppPop.sheet` / `AppSheet.show` 支持 `showHeader: false`，真正省略 header 及留白，默认 true 显示 header。`CommonIconButton` 支持可选 Flutter `icon`，与策展资源 `name` 必须二选一，用于已有位图集中缺失的播放 / 暂停符号；触控区、主题、Tooltip 与可访问性共用原组件。原生成图标清单不修改。

通知设置的两个入口统一调用 `openNotificationSettings`，传 `height: SheetDimension.fraction(.5)`，无 header，内部单一滚动容器展示全部未归档习惯。站内行复用公共图标按钮的 44px 触控区，进度嵌入同一行内；标题、轮次与时间同排，状态通过读数和图标表达；顶部细拖动条使用父级手势与同一控制状态。`TimerStatusProgress.height` 只控制绘制轨道厚度，不影响时间投影。习惯提醒选择复用 `CommonWheelPicker` 两列小时 / 分钟，更新 Provider 草稿，不能沿用全局设置滚轮的自动保存语义。
