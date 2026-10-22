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
