# 公共组件

公共组件按 Producer 的职责分类位于 `lib/common/widgets/{action,input,display,navigation,data,charts}/`，Target 自己拥有的组合壳位于 `lib/common/widgets/composition/`，业务与测试统一从 `lib/common/widgets.dart` 导入。组件负责稳定的交互语义、尺寸和 Theme 映射；业务页面只传入数据、状态和回调。弹层统一走 `lib/common/overlay/app_pop.dart` 的 `AppPop`。

目录分类只组织源码，不改变 `componentId` 或 role。`CommonFormSection` 等 Target 组合壳不得冒充 Producer 组件映射；当前 Producer Contract 均有具体 Dart 映射；`AppPop` 仍保持独立弹层边界，不由 Widget barrel 隐式导出。`PbPageTransitions` 承接 `screen-transition`，由 Theme 应用，不是页面可组合的业务 Widget。

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
| `CommonPrimaryTabs`                | 玻璃轨道 + 官方 TabBar indicator 驱动的静态选中面 |
| `CommonSecondaryTabs`              | 官方 TabBar + 从文字行盒定位的 10×5 caret 指示器                 |
| `CommonTabView`                    | 官方 TabBarView 内容切换、页面保活与 swipe 所有权                           |
| `CommonEmptyState`                 | 空数据或未配置状态                                               |
| `CommonSpinner` / `CommonProgress` | 加载指示和进度展示                                               |
| `CommonDivider`                    | 语义分隔线                                                       |
| `CommonAvatar`                     | 人员或主体头像/首字母                                            |
| `CommonBottomNav`                  | 2–5 个顶级页面目的地；固定 icon + label、无顶部指示条            |
| `CommonIcon`                       | 源端公共图标清单、尺寸、tone 和装饰/无障碍语义                |

## 扩展组件

| API | 职责 |
| --- | --- |
| `CommonStepper` | 有界数值输入；按钮、键盘与文本统一回调 |
| `CommonWheelPicker` | 1–3 列独立滚轮；同时承接 duration-picker，外部状态可更新 |
| `CommonRingProgress` / `CommonMetric` / `CommonTag` | 自绘环形进度、指标数值与只读标签 |
| `CommonMiniBars` | 自绘柱状趋势；保留原始读数语义，长序列横向滚动 |
| `CommonHeatmap` | 自绘日期热力图；缺失与零值不同，受控选择，可替换只读图层 |
| `CommonMonthCalendar` | 显式 month/today、UTC 日期、禁用日与自定义日单元；不读取系统日期 |
| `CommonListCell` / `CommonGroupedList` | Row 样式列表单元与稳定分组；使用外层滚动 |
| `CommonBrandMark` | 品牌资源/Widget 槽位，缺资源时名称兜底 |
| `CommonLaunchScreen` | Flutter 欢迎页或静态启动页；导航与忙碌状态由调用者控制 |
| `CommonGlassSurface` | unified_popups 的玻璃容器，支持高对比度/显式实色降级 |

`CommonDecisionActions` 统一单个主要按钮或左次要、右主要按钮；`CommonFlowSheetContent` 提供固定步骤点和页脚按钮、独立滚动正文。二者是组合辅助，不新增 Producer componentId。图表和日历不创建第二套状态或弹层。

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

业务代码只调 `AppPop`，不直接调 `Pop`。需要样式的 AppPop 方法显式接收调用处 `BuildContext`，并统一转换 Theme、Token 与材质。

`CommonGlassSurface` 组合使用 unified_popups 的 LiquidGlass；明确轮廓，提供清透和实色降级。`AppPop.actionSheet` 是 Sheet 内的动作列表组合。

公共组件不保留旧构造参数或历史别名；feature 必须直接迁移到当前 API。

## 重要语义边界

- `CommonBadge` 是展示语义，`CommonChip` 可以有选择交互；两者不能按外观互换。
- `CommonFilterBar` 负责筛选布局和选中状态，不能用任意 `Wrap` 拼出等价实现。
- `CommonScrollableDataList` 负责刷新、加载更多和 footer，不能用普通 `ListView` 静默替代。
- `CommonFormSection` 负责表单分组，不等于带边框的 `CommonCard`。
- `CommonSwitch` 和 `CommonCheckbox` 的交互语义不同。
- `LiquidGlassDecoration` 是 `CommonPrimaryTabs` 的 Target 私有材质适配，不是新的公共组件或 ProtoBridge componentId；位置、宽度、滚动与动画必须由官方 `TabBar.indicator` 管理。

## 受控交互契约

- `CommonFilterBar` 必须接收可写的选中状态，并通过完整回调更新页面状态；回调后可见内容必须反映筛选结果。
- `CommonSearchBar` 有查询语义时必须连接到当前可见列表或空态；不能只更新输入框文本。
- `CommonScrollableDataList` 的刷新必须更新可观察的加载或数据状态，并在完成后反馈结果。
- `CommonMenuField`、`CommonRadioGroup`、`CommonSwitch`、`CommonCheckbox` 和按钮不得提交空的 `onSelected`、`onChanged`、`onPressed` 或等价回调。
- 页面负责把组件状态接入业务模型；组件负责稳定的交互语义、尺寸和 Theme 映射。

## 参数和实现依据

- 先检查组件构造参数和相似页面，再决定视觉变体。
- 组件内部已有的尺寸、圆角、边框和颜色必须优先通过 `TS` 继承。
- Evidence 要求组件存在但本地组件参数不足时，先报告缺口，再决定是否扩展组件；不要在 feature 中手写第二份公共实现。
- 组件示例以公共组件测试和展示目录为准；展示工程根部区分主题与组件，各类示例通过独立页面进入。
- 精确 DS component id 落点以 [proto-bridge.md](proto-bridge.md) 与工程根目录 `../proto-bridge.target.json` 为准；映射不是靠本表的外观描述推断。

PrimaryTabs 本身只提供选择条，TabView 是可选的独立视口。局部范围或模式选择使用选择条和受控回调，不创建空 TabView。
