# 开发环境

本地和 GitHub Actions 使用同一套版本。Flutter 版本写在 `pubspec.yaml` 的 `environment.flutter`，工作流用 `flutter-version-file` 读取。换电脑或修改本机 PATH 不会改变云端安装的工具。依赖解析遵守 `pubspec.lock`。

## 环境版本与配置位置

| 工具 / 配置 | 当前约定 | 配置位置与升级影响 |
| --- | --- | --- |
| Flutter / Dart | Flutter 3.47.8 / Dart 3.13.7，stable；Dart 约束 `^3.12.0` | `pubspec.yaml` 的 `environment.flutter`；工作流两个 Flutter 安装步骤用 `flutter-version-file: pubspec.yaml` 读取。Dart 随 Flutter 提供，约束在 `environment.sdk` |
| Node.js | 项目脚本使用 22 主版本 | 工作流各 `node-version`；本地需自行安装；小版本可能更新 |
| Java | 构建使用 Temurin 17；Java / Kotlin 目标为 17 | 工作流 `setup-java`、`android/app/build.gradle.kts`；根工程把 Android library 的编译目标设为 17。Android SDK 工具安装使用 runner 的 Java 21 |
| Android SDK / NDK | platform 36，NDK 28.2.13676358；min 24 / target 36 | 工作流安装所需组件；app Gradle 的 compile / min / target / NDK 从 Flutter 工具链读取 |
| Android CMake | 3.22.1 | 工作流通过 Android SDK 的 sdkmanager 安装，原生插件构建使用 Android 工具链 |
| Gradle / Android 插件 / Kotlin | Gradle 9.3.1、AGP 9.1.0、Kotlin 2.4.0；应用使用 AGP 内置 Kotlin，`android.newDsl=false` | `android/gradle/wrapper/gradle-wrapper.properties`、`android/settings.gradle.kts`、`android/gradle.properties` |
| CI runner | ubuntu-22.04 | 工作流 `runs-on`；runner 镜像与预装工具可能更新，不是完全冻结的构建镜像 |
| iOS 本地工具 | macOS、Xcode、CocoaPods、可在 PATH 找到的 CMake | Xcode 选择与签名由本机管理；仓库使用 CocoaPods，`pubspec.yaml` 关闭 Swift Package Manager |
| iOS 部署与身份 | iOS 15.0；主应用 `com.protobridge.yike`，扩展 `.widgets` | `ios/Runner.xcodeproj/project.pbxproj`、entitlements 与 [原生组件](system-surfaces.md)；工程中的 Team 字段不代表新设备自动具备签名权限 |

GitHub Action 自身通过完整提交 SHA 固定版本。Action 内部的 Node.js 24 与项目脚本的 Node.js 22 是两个运行环境；升级 upload / download Action 不等于升级项目 Node。工作流安装的 SDK 包有明确版本，但 Node / Java 的主版本、runner 镜像和 latest 命令行工具仍可能接收更新。

## 本地准备与运行

安装 Flutter 后将 `flutter` / `dart` 加入 PATH；若使用 FVM 等版本管理器，确认终端实际选中的版本。Android 安装 Android Studio / SDK、JDK，配置 SDK 路径并按工具提示完成许可。不要把本机 `android/local.properties` 提交到仓库。

```bash
flutter --version
node --version
java -version
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id>
```

CMake 是 flutter_soloud 的 iOS 原生构建依赖。CocoaPods 脚本不读取 `~/.zshrc`，只在 `/opt/homebrew/bin`、`/usr/local/bin` 以及进程已经继承的 PATH 中查找 `cmake`。官方包若只解压到 `~/.local/opt`，Xcode 脚本阶段仍然报未安装。`/opt/homebrew/bin/cmake` 或 `/usr/local/bin/cmake` 已能运行时先检查，不重复安装。`build/` 里的解压目录不会被脚本使用。Android CMake 3.22.1 由 SDK 提供，不能代替这条 PATH。

以下为本项目使用的官方 macOS 通用包方案。Apple Silicon 的 Homebrew 目录可写时链接到 `/opt/homebrew/bin`；否则改为 `/usr/local/bin`。

```bash
mkdir -p "$HOME/.local/opt"
curl -fL -o /tmp/cmake-4.4.4-macos-universal.tar.gz \
  https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-macos-universal.tar.gz
echo "4b7b73704b1db9b374e5c9ab8e17ac6148b817b6396ee75cd94a852cbac9d305  /tmp/cmake-4.4.4-macos-universal.tar.gz" | shasum -a 256 -c -
tar -xzf /tmp/cmake-4.4.4-macos-universal.tar.gz -C "$HOME/.local/opt"
ln -sfn "$HOME/.local/opt/cmake-4.4.4-macos-universal/CMake.app/Contents/bin/cmake" /opt/homebrew/bin/cmake
cmake --version
```

摘要来自该版本发布的 `cmake-4.4.4-SHA-256.txt`。打开 `ios/Runner.xcworkspace` 配置本机可用的签名；Xcode 许可、开发者账号和证书由用户管理，不自动变更账户或替用户接受许可。

## 换设备

1. 获取仓库并安装上述工具，核对 Flutter、Node、Java 与 SDK 版本。
2. 解析锁定依赖，运行 [客户端检查](testing.md#工程检查) 和所需平台构建。
3. 本地构建正式 APK 时，安全恢复原来的 keystore 和 `key.properties`，不要重新生成替代签名；仅使用云端构建时，现有 GitHub Secrets 不受换设备影响。
4. iOS 重新确认本机签名、App Group 和扩展配置；Android 设备需自行授权调试。

签名、API Key 与密码不写进文档、日志或仓库。工具缓存、Pods、`.dart_tool/`、`build/` 均为本地生成内容。

## 升级工具链

升级前同时核对工作流和项目配置，不能只改本机工具或一个 Action 版本：Flutter / Dart、Gradle / AGP / Kotlin、Java、Android SDK / NDK / CMake 以及插件可能存在兼容关系。依赖更新同时检查 `pubspec.yaml` 与 `pubspec.lock`；iOS 变化核对 Podfile、锁文件和扩展部署目标。

完成修改后先运行 `node tool/verify.mjs`，再按变更执行 Android / iOS 原生构建。Action 上传下载升级需验证产物传递；需要真实发布验证时，另获用户明确授权再触发蒲公英发布。具体签名与发布步骤见 [Android 构建与发布](android-build.md)。版本更新后同步本页和 README 摘要，避免只更新一处。
