# 测试与视觉验证

## 工程检查

在工程根目录运行完整检查入口与独立主题检查：

```bash
node tool/verify.mjs
node tool/ds-theme.mjs
```

`verify.mjs` 依次执行 `flutter pub get`、Dart 格式门禁、完整 `flutter analyze`、完整 `flutter test` 和 DS 同步校验。已在入口中执行的检查不必重复运行。需要单独定位问题时使用：

```bash
flutter analyze
flutter test
node tool/ds-sync.mjs
```

修改公共组件、路由或 Theme 时，完整分析和测试是必要检查。主题门禁核对当前 Token 清单；完整 DS 门禁同时核对当前组件、主题、图标与同步基线。后两者通过 `.pb-scaffold.json` 定位外部 Producer，须保证对应目录及构建产物可用。同步通过不代表业务或视觉已验收。

只修改文档时还需核查 Markdown 链接及锚点、改名后的引用、入口与现有代码是否一致；涉及组件或 Token 索引时执行对应 DS 门禁。不要为了核对文档运行会改写 DS 生成文件的导出命令。

## Widget 场景

Widget test 应从 `ProviderScope` 启动应用，并用 `FakeAppPrefs` override `appPrefsProvider`；生产存储仍只有 MMKV。通过命名路由、根 Tab 和可见操作进入场景。固定 Evidence 任务以选中 Case 为范围，其它任务按产品规则与变更行为验证。

至少检查：

- 页面首次加载和主要导航；
- 选中/未选中、空态、加载态和错误态中被任务选中的状态；
- 计时模式切换、打卡、编辑校验、确认取消、返回和日期选择等任务涉及的交互。

`test/yike_ui_test.dart` 覆盖三主题、主要导航和页面交互；其余公共组件、主题、启动与偏好测试按各自职责拆分。仅验证内存展示状态的测试不能证明真实计时、结算或重开恢复已实现。

## 原生存储验证

`test/app_prefs_test.dart` 检查类型、缺失与损坏区分、写前校验及故障；`test/features/local_data/` 检查业务重试、配置恢复、已开始的会话不被新时长改写，以及保存失败时面板保留。以上使用测试替身，不能替代真实 MMKV。

移动设备上运行真实 MMKV 的实例重开、删除、损坏 JSON 保留及容器完整性保护：

```bash
flutter test integration_test/mmkv_storage_test.dart -d <device-id>
```

计时设置的进程重启测试分两次执行，保持同一设备与应用数据目录：

```bash
flutter test integration_test/timing_persistence_test.dart -d <device-id> --no-uninstall --dart-define=YIKE_STORAGE_PHASE=write
# 确认写入测试结束、旧进程退出，再启动读取测试
flutter test integration_test/timing_persistence_test.dart -d <device-id> --no-uninstall --dart-define=YIKE_STORAGE_PHASE=read
```

两次测试必须使用 `--no-uninstall`，默认卸载会删除应用数据目录。测试记录进程 PID；读取阶段先确认已有磁盘值，再启动应用。通过设置页面写入 26 分钟、每 3 轮长休、5 秒阈值、关闭提示音和 `[181, null, 600, 1200]` 预设，重启后检查配置和专注页 `26:00`。测试使用独立的 `yike_timing_integration` 实例，写入阶段只清理该实例的测试快照；生产 `yike` 实例不受影响。写入阶段不额外调用 flush 或 close，以验证普通写入路径。实际磁盘写满使用故障注入验证，不以模拟故障冒充原生文件系统写满。

## 移动视觉验证

Evidence 指定设备时，优先使用相同设备的 Simulator/Emulator。当前 iPhone 14 Evidence 对应 `390x844` logical viewport。macOS 上可以：

```bash
flutter devices
flutter run -d <device-id>
xcrun simctl io <udid> screenshot <path>
```

截图前必须通过目标路由进入指定场景并等待动画/异步状态稳定。截图只能作为同尺寸视觉检查的结果，不能替代结构和交互测试。

如果没有可用移动设备，必须区分报告：静态检查和 Widget test 可以通过，但视觉验证未执行；桌面/Web 结果不能宣称等价于移动 Screenshot。

动效需在正常运动偏好与减少动态效果下分别运行，覆盖中断、快速连续操作、返回和恢复。静态截图或相同参数不能证明过程一致；本项目固定采集压制动态效果，正常动效要求见 UI 文档，当前未验证项见已知缺口。

## iOS 依赖

工程通过 CocoaPods 接入原生依赖，`pubspec.yaml` 显式关闭 Swift Package Manager。依赖要求以该文件及锁文件为准，不把历史工具链问题写成固定版本禁令。`Pods/`、`.symlinks/` 与 `build/` 为生成目录，不提交。

测试宿主遵守 [状态管理规范](architecture.md#状态管理)。单独挂载 Consumer 组件时由宿主提供 ProviderScope；启动入口自行建立根作用域，偏好与主题作用域覆盖须覆盖实际依赖。

## 体验回归与原生截图

`test/experience_regression_test.dart` 覆盖模式请求提交时机、关闭/遮罩/返回取消、短时确认、空周与仅打卡周、日期明细留白、全年方格、滚轮单位距离及整列手势、归档完成事实和减少动态效果；`theme_context_test.dart` 同时核对三种数字文字角色在主题插值中的连续性。

在移动设备运行可重复的三主题体验检查：

```bash
flutter test integration_test/experience_test.dart -d <device-id> --no-uninstall
```

测试使用 FakeAppPrefs 内存实例，不读写生产 `yike` 数据。每个主题进入计时切换、时长滚轮、FlowSheet、习惯详情浅深模式、空周、日期明细、仅打卡周与月历，输出 9 张原生截图；日志中的 `YIKE_SCREENSHOT=` 是设备临时目录路径。iOS Simulator 的绝对路径可在宿主机查看或复制，Android 需从测试应用临时目录取回。采集时需及时复制到宿主机，测试退出后设备临时目录可能被清理。截图需人工目视检查，不因脚本通过自动认定视觉接受；当前脚本的范围也不等于全部固定 Evidence Case。


## 布局精修回归

`test/layout_polish_test.dart` 检查滚轮数字自身居中及大字体缩放、FlowSheet 可选进度不留空位、倒计时等宽选项和取消语义、计圈基线与滚动、日期按压与无选择语义、手机安全区内操作、每日详情长列表与固定翻日。

```bash
flutter test integration_test/layout_polish_test.dart -d <移动设备 ID>
```

此脚本使用内存存储与固定日期，三主题各输出 11 张截图，覆盖倒计时、时长滚轮、计圈浅深、每日记录浅深、空日、周/月按压及关闭步骤指示的 FlowSheet；日志前缀为 `YIKE_POLISH_SCREENSHOT=`。按压截图使用设备事件来源，避免测试框架的彩色触点覆盖图形。截图应在运行期间复制到宿主机，再人工复核；最近一轮结果见 [布局与交互精修](reviews/2026-10-23-layout-polish.md)。
