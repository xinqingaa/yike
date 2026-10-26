# 一刻 · Yike

一刻是本地使用的 Flutter 专注与习惯工具，提供番茄钟、正计时与计圈、倒计时、习惯打卡、周月回顾和统计。机械、水位、日影三套主题支持浅色、深色和跟随系统；数据保存在本机，无账号和云同步。

番茄钟、正计时和倒计时可以同时运行，支持表盘调时、主题声音与触感、后台到点提醒。桌面组件展示专注和打卡进度，iOS 实时活动与动态岛提供应用外的计时预览及暂停 / 继续入口。产品和工程说明见 [文档索引](docs/README.md)。

## 快速开始

建议使用与 CI 一致的 Flutter 3.44.0（Dart 3.12.0）及 Node.js 22。Android 需要 JDK 和 Android SDK；iOS 需要 macOS、Xcode、CocoaPods 与 CMake。安装、换设备和版本升级见 [开发环境](docs/engineering/development-environment.md)。

```bash
flutter pub get
flutter devices
flutter run -d <device-id>

# 完整客户端检查
node tool/verify.mjs
```

## Android 打包与发布

进入 [Android build · 打包与蒲公英发布](https://github.com/xinqingaa/yike/actions/workflows/android-build.yml)，点击 **Run workflow**，选择 `main` 和所需操作：

| 操作 | 结果 |
| --- | --- |
| 发布到蒲公英（默认） | 完整检查、正式签名构建、上传并确认发布，Summary 提供下载链接与二维码 |
| 只构建正式 APK | 完整检查、正式签名构建，在运行页面下载产物 |
| 只构建内测 APK | 完整检查、临时 debug 签名构建，仅用于构建核验 |

main 推送和 PR 更新只运行检查，不打包；纯 Markdown 变更只检查文档。APK 构建与发布均按需手动触发，产物保留 30 天。Secrets、长期签名备份、包体优化及故障处理见 [Android 构建与发布](docs/engineering/android-build.md)。

本地可运行 `node tool/build-android.mjs --preview` 构建内测 APK；正式包使用长期签名。云端内测包使用临时签名，日常手机安装和后续覆盖更新应使用同一长期正式签名。

CI 在 GitHub runner 上独立准备 Flutter 3.44.0、Node.js 22、Java 17、Android SDK 36、NDK 28.2.13676358、CMake 3.22.1；本地换设备不会改变云端环境。升级入口和兼容性说明见 [环境版本与配置位置](docs/engineering/development-environment.md#环境版本与配置位置)。

## 文档与协作

- [文档索引](docs/README.md)：产品与工程说明。
- [产品与交互](docs/product/product.md)：页面职责、计时、打卡和统计。
- [开发环境](docs/engineering/development-environment.md)：本地运行、云端工具链、换设备与升级。
- [Android 构建与发布](docs/engineering/android-build.md)：签名、Secrets、手动发布与产物。
- [协作规则](docs/workflow.md)与 [AGENTS](AGENTS.md)：任务实施、文档维护和 Git 授权。
- [已知缺口](docs/known-gaps.md)：问题与测量边界。

主文档放在 `docs/`，README 和 AGENTS 保持入口职责。未经用户明确允许，不提交或推送 Git；批准实施不代表批准提交、推送或合并。
