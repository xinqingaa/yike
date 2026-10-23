# ProtoBridge 目标适配

本页仅用于用户明确要求的原型迁移、固定 Evidence 核对、还原验收或 DS 同步。日常 Flutter 功能、UI 和动效以本地规范为依据，不自动进入本页流程。

Producer Contract 决定职责、状态、布局、Token 槽和可观察行为；Flutter 采用本平台的组件与 API 承接，不复制 Vue props、DOM 或手势实现。精确映射由根目录 `proto-bridge.target.json` 拥有；本文索引受文档校验约束。

## 组件索引

当前登记的 componentId 均有 Dart 公开入口。`resolved` 证明声明、导入、定义和使用可定位，不代表已经完成某份业务 Evidence 的视觉验收。

| Evidence | Target | import |
| --- | --- | --- |
| `action-sheet` | `AppPop.actionSheet` | `lib/common/overlay/app_pop.dart` |
| `app-bar` | `CommonAppBar` | `lib/common/widgets/navigation/app_bar.dart` |
| `avatar` | `CommonAvatar` | `lib/common/widgets/display/avatar.dart` |
| `badge` | `CommonBadge` | `lib/common/widgets/display/badge.dart` |
| `bottom-sheet` | `AppPop.sheet` | `lib/common/overlay/app_pop.dart` |
| `brand-mark` | `CommonBrandMark` | `lib/common/widgets/display/brand_mark.dart` |
| `button` | `CommonButton` | `lib/common/widgets/action/button.dart` |
| `card` | `CommonCard` | `lib/common/widgets/display/card.dart` |
| `checkbox` | `CommonCheckbox` | `lib/common/widgets/input/checkbox.dart` |
| `chip` | `CommonChip` | `lib/common/widgets/display/chip.dart` |
| `confirm` | `AppPop.confirm` | `lib/common/overlay/app_pop.dart` |
| `data-list` | `CommonDataList` | `lib/common/widgets/data/data_list.dart` |
| `divider` | `CommonDivider` | `lib/common/widgets/display/divider.dart` |
| `duration-picker` | `CommonWheelPicker` | `lib/common/widgets/input/wheel_picker.dart` |
| `empty-state` | `CommonEmptyState` | `lib/common/widgets/display/empty_state.dart` |
| `filter-bar` | `CommonFilterBar` | `lib/common/widgets/navigation/filter_bar.dart` |
| `flow-sheet` | `AppPop.flowSheet` | `lib/common/overlay/app_pop.dart` |
| `glass-surface` | `CommonGlassSurface` | `lib/common/widgets/display/glass_surface.dart` |
| `grouped-list` | `CommonGroupedList` | `lib/common/widgets/data/grouped_list.dart` |
| `heatmap` | `CommonHeatmap` | `lib/common/widgets/charts/heatmap.dart` |
| `icon` | `CommonIcon` | `lib/common/widgets/action/icon.dart` |
| `icon-button` | `CommonIconButton` | `lib/common/widgets/action/icon_button.dart` |
| `launch-screen` | `CommonLaunchScreen` | `lib/common/widgets/navigation/launch_screen.dart` |
| `list-cell` | `CommonListCell` | `lib/common/widgets/data/list_cell.dart` |
| `loading` | `AppPop.loading` | `lib/common/overlay/app_pop.dart` |
| `menu` | `AppPop.dropMenu` | `lib/common/overlay/app_pop.dart` |
| `metric` | `CommonMetric` | `lib/common/widgets/display/metric.dart` |
| `mini-bars` | `CommonMiniBars` | `lib/common/widgets/charts/mini_bars.dart` |
| `month-calendar` | `CommonMonthCalendar` | `lib/common/widgets/charts/month_calendar.dart` |
| `primary-tabs` | `CommonPrimaryTabs` | `lib/common/widgets/navigation/primary_tabs.dart` |
| `progress` | `CommonProgress` | `lib/common/widgets/display/progress.dart` |
| `radio-group` | `CommonRadioGroup` | `lib/common/widgets/input/radio_group.dart` |
| `ring-progress` | `CommonRingProgress` | `lib/common/widgets/display/ring_progress.dart` |
| `screen-transition` | `PbPageTransitions.theme` | `lib/common/widgets/navigation/screen_transition.dart` |
| `scrollable-data-list` | `CommonScrollableDataList` | `lib/common/widgets/data/scrollable_data_list.dart` |
| `search-bar` | `CommonSearchBar` | `lib/common/widgets/input/search_bar.dart` |
| `secondary-tabs` | `CommonSecondaryTabs` | `lib/common/widgets/navigation/secondary_tabs.dart` |
| `spinner` | `CommonSpinner` | `lib/common/widgets/display/spinner.dart` |
| `stepper` | `CommonStepper` | `lib/common/widgets/input/stepper.dart` |
| `switch` | `CommonSwitch` | `lib/common/widgets/input/switch_control.dart` |
| `tab-viewport` | `CommonTabView` | `lib/common/widgets/navigation/tab_view.dart` |
| `tabbar` | `CommonBottomNav` | `lib/common/widgets/navigation/bottom_nav.dart` |
| `tag` | `CommonTag` | `lib/common/widgets/display/tag.dart` |
| `text-field` | `CommonTextField` | `lib/common/widgets/input/text_field.dart` |
| `textarea` | `CommonTextArea` | `lib/common/widgets/input/text_area.dart` |
| `toast` | `AppPop.toast` | `lib/common/overlay/app_pop.dart` |

`page`、`section`、`summary`、`list` 和 `field` 等通用 role 不能覆盖更精确的 componentId。CommonFormSection、CommonDecisionActions 和 CommonFlowSheetContent 是 Target 组合壳，不是新增的 Producer componentId。

## Token mapping

当前可绑定主题键映射到上下文主题实例的 accessor，例如 `ts.colors.primary`；先通过 `TS.of(context)` 获得该实例。`protoBridgeTokenSnapshot(ts)` 提供可执行使用点。不可绑定 enum、派生部件和实现常量不建立映射，`transparent` 与 `none` 是字面量。

主题只有类型化 AppThemePack 与 ThemeExtension 一条路径，详细规则见 [Theme](../engineering/theme.md)。资源可以为空，组件按 Contract 回退；有品牌或插画 Evidence 时由目标产品主题包提供实际资源或公开 Widget 插槽。

## 原生实现与组合边界

- AppBar、底部导航和各级 Tabs 使用官方组件。一级轨道使用 CommonGlassSurface，选中底由官方 TabBar.indicator 连续定位；底部导航在官方等宽目的地后绘制一份滑动选中面。次级 Tab 保留文字中心上三角。
- CommonTabView 使用 TabBarView 与可配置保活；页面按区域关闭不需要的 swipe，Flutter Gesture Arena 负责仲裁。
- CommonIcon 用 Image.asset 消费 DS 注册源的高分辨率图片，图标名称由导出器生成，不使用同名字体图标替换。来源、图层与颜色规则见 [资源规范](../engineering/assets.md)。
- Button 公开六种动作、rounded/pill 和 solid/glass；loading 保留文字并阻止重复触发，disabled 才降低整体透明度。
- 字段标签独立放在官方输入表面上方。Checkbox、RadioGroup、Switch 的实例色槽必须由上下文 Theme Token 解析，不能传硬编码颜色；Switch 支持标签前后位置。
- DataList 使用 ListView；ScrollableDataList 统一管理刷新、加载、异常和控制器释放。GroupedList 是外层滚动中的 Row 单元组合，不创建嵌套滚动。
- 所有弹层经 AppPop 调用远程 unified_popups；需要样式的方法接收调用处 BuildContext。库拥有 Overlay、关闭、焦点、键盘、拖拽、路由与生命周期。ActionSheet 复用 Sheet。
- Sheet 的 content/medium/expanded 由库的 `SheetSizeConfig` 表达；medium/expanded 使用 `ts.sizing.panelMedium` / `panelLarge` 的 fraction。档位由调用者选择，拖动关闭由库管理，不复制 Web 的档位切换手势。
- FlowSheet 内部页面使用 CommonFlowSheetContent：滚动主体、固定步骤指示和决策区。头部返回调用库控制器，关闭结束整张 Sheet，不把返回等同于提交。决策区通过 CommonDecisionActions 保持一颗主要动作或左次要右主要。
- GlassSurface 组合库内 LiquidGlass，边缘由其 Painter 绘制，背景由 BackdropFilter 模糊；高对比或显式减少透明度时使用实色。
- 滚轮是独立一至三列的原生 ListWheelScrollView，不做业务时长换算。Stepper 的键盘与按钮统一使用有限值、step 与 min/max 规则。
- MiniBars、Heatmap 和 RingProgress 使用 CustomPainter。日期计算只用传入的 UTC 日期；Heatmap 区分缺失与零值，限制展示区间，支持只读绘图与图例替换。MonthCalendar 管理日期、焦点和禁用，dayBuilder 只替换内容。
- BrandMark 提供 mark/wordmark Widget 替换与名称回退。LaunchScreen 是 Flutter 欢迎/静态页面，不包含原生首帧前启动资源，也不自动延时跳转。

## 明确的平台翻译

- 页面和 FlowSheet 使用官方 Route／库内 Navigator 与返回机制；不复制 Web 的拖动阈值、前进横滑或指针仲裁算法。FlowSheet 的前进由动作推进，返回使用库内返回或官方侧滑。
- CSS 饱和度、内阴影与多层 elevation 翻译为 LiquidGlassStyle、边缘 Painter、BoxShadow 或 Material elevation；不声称原生光学折射或跨平台像素完全一致。
- Native 控件保留平台的键盘、焦点、字号缩放和触控行为；目标 API 不要求与 Vue 同名同构。图形与材质的性能需要在实际设备场景检查，不能由 resolver 成功推导。

## Resolver 与同步状态

映射与实际代码不一致返回 stale，政策与机器声明冲突返回 conflict。未实现的条目只能声明带非空 reason 的 pending，不得静默换成别的组件；pending 与同一 ID 的具体映射不能并存。

条目 pending 表示该键待实现；`proto-bridge.sync.json` 的批次 pending 表示整个 surface 尚未确认同步，两者不同。同步基线固定 Schema、Contract、role、图标、Token、主题与绑定池的完整 fingerprint。稳定后用 verifier 输出整体更新，不能只改一个 digest。

## 平台外观与适配上下文

Flutter AppBar 保留玻璃背景及底边，去掉顶部/两侧边缘和环绕阴影；其状态栏样式根据实际合成背景显式指定，无 AppBar 页面由应用根提供默认样式。

Target 适配器只提供目标上下文，不把 Target 事实写入 Evidence。本仓库需要的适配约束由本页维护，不依赖外仓架构文档。官方 Flutter MCP Runtime Review 属于保留实验，不要求目标携带专用 Driver、Case 副本或 build identity。

交付、同步与 Review 入口统一见 [协作与工作流](../workflow.md)，检查方式见 [测试与视觉验证](../engineering/testing.md)。

## 专项流程与交付

固定 Evidence 任务经 Consumer Skill 读取固定 Workspace、Handoff、Bundle、Snapshot 和 revision，报告原始 mandatoryRisks、选定范围、组件/Token pending 与平台差异。实际截图、Case 与 Scenario 的覆盖分别记录，五维还原 Review 不等同于最终人工视觉接受。

普通客户端检查通过后，专项按需要执行 `node tool/ds-theme.mjs` 或 `node tool/ds-sync.mjs`；两者读取外部 Producer，必须明确同步范围与源版本。MCP 配置经 `tool/mcp.mjs` 与 `.pb-scaffold.json` 定位，只在专项中检查 workspace target 绑定；修改绑定需属于已授权范围。

仅要求评估时先给方案；已批准的实施范围持续有效，不为同一专项重新要求批准。专项完成后报告固定引用、风险、状态/交互覆盖、Target validation、五维 Review 完整度及原生验证边界。

历史固定证据不能被 Producer 当前源码或 active/latest 替换。获批准的 Flutter 产品变化不需要修改历史 Evidence；记录差异及其决策即可。外部工具限制不会阻断无关客户端开发。

## 本地专项协议

本页与仓库内的三个专项 Skill 维护 Target 侧工作规则，无需先打开外部仓库的说明文档。专项确需外部输入时，只读取任务指定的固定 Evidence、变更 Contract 或执行已授权的生成/校验工具，不把外仓文档作为普通开发的先决条件。

DS 同步先记录源版本、Schema、Contract、role、Token/Theme、组件及图标的变化范围；再核对职责、状态、布局、visual anatomy 与 Token binding，使用 Flutter 公开 API 实现。主题和图标来自同一已选定源范围；导入的 Dart/PNG/清单只经导出工具更新。精确路径与颜色策略在本仓库 [资源规范](../engineering/assets.md) 维护，不要求先阅读 Producer 图标说明。

当前专用导出入口是 Producer 根目录的 `scripts/export-flutter-themes.mjs` 与 `scripts/export-flutter-icons.mjs`，支持 `--prototype <id>` 和 `--target <directory>`。它们是显式同步使用的外部工具，不是本文的文档依赖；源目录经本地 `.pb-scaffold.json` 配置定位，缺失时只影响该专项。

同步后核对实际生成实现、资源尺寸、模式矩阵、完整映射与本地检查，记录 pending reason 和平台近似。批次仍有 drift 时保持 pending，不为了消除差异只更新 fingerprint。源端已发生与本页不符的协议变化时报告具体差异并修订本地适配规则，不暗中追随外部文档或分支。
