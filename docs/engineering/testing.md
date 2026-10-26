# 测试与视觉验证

## 工程检查

在工程根目录运行独立客户端检查：

```bash
node tool/verify.mjs
```

依次执行本地文档链接/锚点检查、蒲公英发布脚本的 Node 模拟回归、`flutter pub get`、Dart 格式门禁、`flutter analyze` 和完整 `flutter test`。本地映射测试验证导入基线的可访问性，不读取外部 Producer。已在入口执行的检查不必重复运行；定位时可单独运行 `node tool/check-docs.mjs`、`flutter analyze` 或指定测试文件。

静态分析排除 `build/**` 生成目录，避免历史临时审计脚本进入源码门禁。Android APK 的本地 / 云端构建、签名与产物核验见 [Android 构建与签名](android-build.md)。

只改文档运行文档检查并核对内容；公共组件、路由、Theme 或运行机制变化执行完整检查。`tool/ds-sync.mjs` 和 `tool/ds-theme.mjs` 仅用于用户明确要求的外部 DS 专项，依赖外部 Producer，不属于日常客户端门禁。不要为文档检查运行改写生成资源的同步命令。

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

普通 Flutter 任务按目标移动设备和产品场景验证；现有手机布局基准为 `390×844` 逻辑视口，并补充窄屏与大文字缩放。明确的固定 Evidence 专项才需要对齐其指定设备。macOS 上可以：

```bash
flutter devices
flutter run -d <device-id>
xcrun simctl io <udid> screenshot <path>
```

截图前必须通过目标路由进入指定场景并等待动画/异步状态稳定。截图只能作为同尺寸视觉检查的结果，不能替代结构和交互测试。

如果没有可用移动设备，必须区分报告：静态检查和 Widget test 可以通过，但视觉验证未执行；桌面/Web 结果不能宣称等价于移动 Screenshot。

动效需在正常运动偏好与减少动态效果下分别运行，覆盖中断、快速连续操作、返回和恢复。静态截图或相同参数不能证明过程一致；历史固定采集压制动态效果，当前过程要求见 [动效规格](../product/motion.md)，未验证项见 [已知缺口](../known-gaps.md)。

## iOS 依赖

第一阶段 flutter_soloud 4.1.7 的 iOS 原生构建需要 PATH 中能找到 CMake（包内 CocoaPods 脚本调用 `cmake`）。缺少工具时先确认本机安装方案，不修改 SDK 或强制覆盖依赖。2026-10-24 本机因 Homebrew 与 Command Line Tools 不兼容，经用户确认使用官方 CMake 4.4.4 macOS 通用包。换设备时按 [README 运行](../../README.md#运行) 下载、校验并解压到用户目录，再把 PATH 写入该设备的 shell 配置。已能在 PATH 中找到 CMake 的机器不必改用此路径：

```bash
export PATH="$HOME/.local/opt/cmake-4.4.4-macos-universal/CMake.app/Contents/bin:$PATH"
```

Android 构建使用 Android SDK 自带的 CMake 3.22.1，不读取这条 PATH。运行入口见 [README](../../README.md#运行)。

工程通过 CocoaPods 接入原生依赖，`pubspec.yaml` 显式关闭 Swift Package Manager。iOS 部署目标为 15.0，与当前 Xcode 支持的最低部署版本一致。依赖要求以该文件及锁文件为准，不把历史工具链问题写成固定版本禁令。`Pods/`、`.symlinks/` 与 `build/` 为生成目录，不提交。

测试宿主遵守 [状态管理规范](architecture.md#状态管理)。单独挂载 Consumer 组件时由宿主提供 ProviderScope；启动入口自行建立根作用域，偏好与主题作用域覆盖须覆盖实际依赖。

## 体验回归与原生截图

`test/experience_regression_test.dart` 覆盖并行模式切换保留运行 / 暂停会话、显式结束的短时确认、空周与仅打卡周、日期明细留白、全年方格、滚轮单位距离及整列手势、归档完成事实和减少动态效果；`theme_context_test.dart` 同时核对三种数字文字角色在主题插值中的连续性。

历史体验专用截图脚本已于 2026-10-25 随用户验收清理；长期行为覆盖留在 `test/experience_regression_test.dart`。需要新的设备视觉检查时按具体 UI 变更安排，不维持已过期的验收夹具。

## 布局精修回归

`test/layout_polish_test.dart` 检查滚轮数字自身居中及大字体缩放、FlowSheet 可选进度不留空位、倒计时等宽选项和取消语义、右侧记圈数字基线、列表滚动与单入口、日期按压与无选择语义、手机安全区内操作、每日详情长列表与固定翻日。

布局精修专用截图脚本已清理；保留上述长期 Widget 回归。历史验证范围见 [布局与交互精修](../reviews/2026-10-23-layout-polish.md)。

## 动效、时间与性能

通过注入 clockProvider 验证真实时间投影、秒边界、暂停冻结、到零及回到前台，不用帧数累加业务时长。连续动画使用有界 pump，检查中间帧与最终态；避免 pumpAndSettle 永远等待。检查只变化数字位、水下副本同步、完成仅当场可见播放、历史/保存重试不重播、打卡撤销重做与列表稳定身份。

原生运行分别覆盖正常/减少动态效果、三主题、浅深、覆盖路由、根 Tab 与后台恢复。过程录屏/分时截图与脚本记录互相补充，单帧不证明连续过程。持久化只通过真实 MMKV 或进程重启验证其声明范围。

profile 在移动真机记录场景、刷新率、样本数量、UI/raster 的 p50/p90/p99 与超预算帧。采样先热身；水位、日影、换主题与长列表分开测。模拟器/debug 可定位功能和布局，不写成真机性能通过。大量历史的初始化/序列化/统计另做有代表性的样本，不以小数据测试替代。

## 本轮动效回归与真机采样

`test/motion/` 检查变化位、同步裁切、暂停、事件实时可见性、同帧合并、列表身份与未保存浮层生命周期。运行中场景使用有界 pump；辅助方法 `test/support/pump_presentation.dart` 只推进呈现帧，不修改注入的业务时钟。

```bash
flutter test integration_test/motion_profile_test.dart -d <真机 ID> --profile --dart-define=YIKE_PROFILE_DEVICE=<设备型号>
```

原生动效专用截图脚本已随验收清理，历史范围见 [实施记录](../reviews/2026-10-23-motion-implementation.md)。可复用的真机性能采样工具保留；profile 脚本要求 profile 模式与设备名称，记录刷新率、125 帧热身、样本量、UI/raster p50/p90/p99 及超预算帧。连续表盘、主题切换、计圈与导航独立采样；相同设备和场景比较前后，不将采样入口本身写成性能已通过。

## 记圈、回顾与统计回归

长期测试：`test/features/review/review_statistics_test.dart` 验证跨日去重/本期最长/开始小时、同期及短月、当前目标参考与趋势窗口；`test/stage34_ui_test.dart` 验证三主题圈控制/完成保留、飞行并发/零圈拒绝/减少动态效果、筛选与返回、筛选时图形位置稳定、日期点击/长按均查看同一 Menu，卡内入口再进入 Sheet、专注卡时长与次数同行、统计二级 Tab 与图表滚动保留、类型环点击联动、统计习惯完成格查看与详情卡一致、无边框铺满色块、数据卡滚动关闭、窄屏大字体。`test/feedback_service_test.dart` 检查查看触感的总开关、可选习惯 scope 和前后台门控。

阶段 3、4 的临时预览入口与原生验收脚本已在用户验收后删除，长期回归留在上述测试。2026-10-25 清理第五阶段临时材料和旧体验 / 布局 / 动效专用截图采集脚本，移除 17 处历史截图失效链接。长期通知 / 反馈回归位于 `test/stage5_notifications_test.dart`、`test/feedback_service_test.dart`，必要替身保留。原生 MMKV、进程重启与性能采样属于可复用工程工具，继续保留。历史 7 项基线失败见 [记录](../plan/stage5-notifications.md#上轮自动化结果)；2026-10-26 CI 接入时已核对现行规则并修复过期测试操作 / 断言，全套 240 项 Flutter 测试通过。历史阶段记录不改写，阶段验收与本次工程检查分别报告。


2026-10-25 站内提示 UI 修订：`test/stage5_notifications_test.dart` 增加不占位、上滑胶囊 / 点击展开、新会话保留收起、暂停图标隔离、收起期间完成不闪回、三主题窄屏大字和无 header 预约详情回归。持续扫光使用有界呈现泵，不用 `pumpAndSettle` 等待静止；页面模式选择应限定顶部 Tab，浮层中同名标题不作为 Tab 目标。原生手感、光效与性能仍由设备验证，不从 Widget 断言推断。
