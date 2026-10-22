# 测试与视觉验证

## 原生检查

在工程根目录运行：

```bash
flutter pub get
flutter analyze
flutter test
node tool/ds-theme.mjs
node tool/ds-sync.mjs
```

修改公共组件、路由或 Theme 时，必须至少运行完整的 `flutter analyze` 和 `flutter test`。主题门禁检查 当前 Token 清单；完整同步门禁同时检查 当前组件清单与当前 DS surface。

## Widget 场景

Widget test 应从 `ProviderScope` 启动应用，并用 `FakeAppPrefs` override `appPrefsProvider`；生产存储仍只有 MMKV。通过命名路由和可见文案进入场景。需要覆盖的状态以固定 Evidence Case 为准；不要只测默认入口。

至少检查：

- 页面首次加载和主要导航；
- 选中/未选中、空态、加载态和错误态中被任务选中的状态；
- 提交、确认、领取或返回等被 Evidence 证明的交互。

## 移动视觉验证

Evidence 指定设备时，优先使用相同设备的 Simulator/Emulator。当前 iPhone 14 Evidence 对应 `390x844` logical viewport。macOS 上可以：

```bash
flutter devices
flutter run -d <device-id>
xcrun simctl io <udid> screenshot <path>
```

截图前必须通过目标路由进入指定场景并等待动画/异步状态稳定。截图只能作为同尺寸视觉检查的结果，不能替代结构和交互测试。

如果没有可用移动设备，必须区分报告：静态检查和 Widget test 可以通过，但视觉验证未执行；桌面/Web 结果不能宣称等价于移动 Screenshot。

## iOS 依赖

工程通过 CocoaPods 接入原生依赖；依赖要求以 `pubspec.yaml` 和锁文件为准。工具链兼容原因统一记录在 Producer 的 Flutter iOS 决策中，不复制为 Skill 版本限制。`Pods/`、`.symlinks/` 与 `build/` 为生成目录，不提交。

公共组件、Demo 和启动行为的测试同样遵守 Riverpod 状态规范，不使用 StatefulBuilder。单独挂载 Consumer 组件时由测试宿主提供 ProviderScope；启动入口自行建立根作用域，偏好与主题作用域覆盖须覆盖实际依赖。
