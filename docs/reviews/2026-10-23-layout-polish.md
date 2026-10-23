# Flutter 布局与交互精修 · 2026-10-23

本轮承接用户批准的第二轮方案，在 Yike Flutter 端直接实施。未调用 ProtoBridge MCP，也未修改 Producer、固定 Evidence 或历史评审；既有 `.codex/config.toml` 和 `.mcp.json` 改动保留。第一轮结果见 [Flutter 体验修复](2026-10-23-flutter-experience.md)，本页记录后续布局与交互调整。

## 实施结果

| 范围 | 当前行为与主要落点 |
| --- | --- |
| 滚轮 | `common/widgets/input/wheel_picker.dart` 中数字自身在每列居中，单位独立位于右侧略靠下；按最长候选值预留稳定宽度，窄列或大字体统一缩放，整列可滚动。`DurationWheels` 使用两位数字和单字“时、分、秒”；次数保留“次/轮” |
| 倒计时 | `focus/widgets/countdown_choices.dart` 提供两列等宽快捷项与独立满行自定义入口，按最长文字计算统一行高，兼容空项、奇数项和长时长。选择不启动计时，关闭自定义不改目标。待开始布局收紧表盘和快捷区的空间，让默认手机视口完整显示开始按钮 |
| 计圈 | `focus/widgets/lap_list.dart` 使用圈次、单圈、累计三列；数字等宽、右对齐、基线对齐。当前/暂停状态位于第一列，最近记录在顶部；按实际表盘高度选择两或三行独立滚动视口。计圈与暂停按钮等高，紧凑布局保留操作空间 |
| 每日明细 | `review/widgets/day_detail_sheet.dart` 独立维护日期、专注合计、打卡次数、开始/类型/时长表格及逐条习惯记录。统一左右留白，正文可滚动，等宽前后翻日固定在底部；空日按内容收缩，长日限制正文高度 |
| 日期动作 | 周图和月历不保留日期选中边框或选中语义；只保留 `lastViewedDate` 供周/月切换定位。`CommonPressableSurface` 在不透明图形上方绘制主题色按压反馈，形状随主题适配，释放后消退；今天标记、键盘焦点和通用月历的受控选择能力保留。打开期间忽略重复请求，关闭后可再次打开同一天 |
| 日期边界 | 每日详情使用相同的日期基准比较前后边界，避免本地日期与 UTC 混用使今天的“后一天”错误可用；仍不跨周/月，也不进入未来 |
| FlowSheet | `CommonFlowSheetContent.progress` 默认空，关闭时不绘制指示器、不预留其高度。线性流程可显式传入 `CommonFlowSheetProgress(step, total)`；现有设置编辑分支默认关闭 |
| 其它对齐 | 回顾类型统计的长总时长受到列宽约束，避免窄屏横向溢出。布局与交互规则同步到组件、UI、逻辑和测试文档 |

上述调整属于用户明确批准的 Flutter 产品变更，不将历史 Evidence 截图改写为新版本。

## 验证

- `node tool/verify.mjs`：依赖准备、Dart 格式、静态分析、156 项单元/Widget 测试以及 DS 同步通过。
- `node tool/ds-theme.mjs` 通过；DS 为 46/46 当前组件、151/151 可绑定主题键，pending 0。
- 新增 `test/layout_polish_test.dart` 18 项场景：一至三列数字中心、0/9/10/59 值、1.6 倍文字、可选进度占位、0/1/3/4 个快捷项、长时长、选择/取消不启动、计圈列边缘与基线、三主题按压与释放、手机安全区内操作、日期无选择语义、范围定位、长日正文滚动与固定翻日。
- 原有业务 UI 测试继续核对跨日分配，明细改用新的时长列定位，仍验证所选日期的 1 分钟用时，而非跨日会话总用时。
- `integration_test/layout_polish_test.dart` 使用 FakeAppPrefs 内存数据、固定日期与可控时钟，在 iPhone 14 / iOS 18.6 Simulator 运行三主题流程；逻辑视口 390×844，原生截图 1170×2532。不读写生产 `yike` 存储。
- 原生检查覆盖默认手机操作区域、12 次计圈、今天禁用后一天、重复打开每日详情、深浅外观、长习惯名、空日、周/月按压和默认关闭的步骤指示。深色详情在切换外观后重新打开，核对打开时的真实深色面板。

## 视觉附件

原生截图三主题各 11 张，共 33 张；宿主机副本与日志位于忽略目录 `build/polish/`。目视复核了数字/单位、网格与开始按钮、计圈三列及操作、明细的三列和固定翻日、浅深材质、日期反馈形状和 FlowSheet 无步骤点状态。截图中的样例是测试夹具，不是用户历史。

- [机械倒计时](../../build/polish/mechanical-countdown.png)、[水位倒计时](../../build/polish/water-countdown.png)、[日影倒计时](../../build/polish/sundial-countdown.png)
- [居中滚轮](../../build/polish/water-duration.png)、[计圈](../../build/polish/water-laps.png)
- [每日记录](../../build/polish/mechanical-day-records.png)、[深色每日记录](../../build/polish/mechanical-day-records-dark.png)、[空日](../../build/polish/sundial-day-empty.png)
- [周图按压](../../build/polish/water-week-pressed.png)、[月历按压](../../build/polish/sundial-month-pressed.png)、[FlowSheet 默认状态](../../build/polish/mechanical-flow-default.png)

完整检查日志为 `verify.log`、`ds-theme.log`、`native.log`，定向几何测试日志为 `layout-tests.log`。清理 build 会移除这些本机附件，需要重新采集。

## 验证边界

本轮未执行 Android 原生流程、真机性能或全部固定 Evidence Case；未声称完成整个应用的视觉验收。弹层已打开期间的系统外观变化没有纳入本轮验收。既有业务动效、通知/音频等缺口继续以 [已知缺口](../known-gaps.md) 为准。
