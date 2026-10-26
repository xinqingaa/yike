# Android 构建与签名

当前发布目标为 arm64 Android 手机，应用 ID 保持 `com.protobridge.yike`。统一入口固定 release 模式、按 ABI 拆包、分离 Dart 调试符号，并归档 APK、R8 mapping 与包含大小 / SHA-256 的构建清单。iOS 配置不在此流程修改。

## 本地构建

需要 Flutter 3.44.0 / Dart 3.12.0、Node.js 22、JDK 17 或兼容版本，以及 Android SDK 36、NDK 28.2.13676358、CMake 3.22.1。版本与当前已验证工具链一致，升级时重新验证。入口执行带锁文件校验的依赖解析；不要手动改写生成的插件注册文件。

```bash
# 生成长期使用的发布签名，仅首次执行。
node tool/create-android-signing.mjs

# 正式签名构建。
node tool/build-android.mjs

# 使用本机 debug key 的 release 模式内测包。
node tool/build-android.mjs --preview

# 覆盖 pubspec 中的版本；同一签名更新时构建号应递增。
node tool/build-android.mjs --build-name 1.0.0 --build-number 2
```

签名生成器调用 JDK 的 keytool；通过 `JAVA_HOME` 选择 JDK。默认将 `yike-release.jks` 和 `key.properties` 保存到用户主目录下的 `.config/yike/signing/`，设置私有权限，不输出密码。两个文件已有任意一个时拒绝覆盖；必须安全备份二者，后续版本沿用同一份签名。

构建入口按以下优先级选择签名配置：`YIKE_ANDROID_KEY_PROPERTIES` 指定的文件、`android/key.properties`、用户目录 `.config/yike/signing/key.properties`。也可通过四个环境变量提供签名：`YIKE_ANDROID_STORE_FILE`、`YIKE_ANDROID_STORE_PASSWORD`、`YIKE_ANDROID_KEY_ALIAS`、`YIKE_ANDROID_KEY_PASSWORD`；环境变量字段优先于文件。相对 storeFile 路径以 `android/` 为基准。正式构建缺少签名时失败，不自动退回 debug key。`--preview` 显式使用本机 debug key。

产物位于 `build/releases/android/release/` 或 `preview/`，包括带版本 / 架构 / 签名模式的 APK、`symbols/` 与 `manifest.json`。目录不提交 Git；保留与已分发版本对应的符号文件用于崩溃还原。Flutter 的 ABI 拆包规则会调整 APK 内的 versionCode，清单中的 flutterBuildNumber 只记录传给 Flutter 的原始构建号；不要在拆包和非拆包流程间任意切换。

## 已固化的体积优化

- 只为 arm64 构建并拆包，排除第三方插件夹带的其它架构库；不适用于 32 位手机和 x86 模拟器。
- 分离 Dart 调试符号，保留 R8 默认代码 / 资源缩减和图标字体裁剪。
- `android/gradle.properties` 中的 `NO_XIPH_LIBS=true` 使用 flutter_soloud 4.1.7 的正式开关，不打包 Opus / Ogg / Vorbis / FLAC 库。现有 9 个效果音均为 PCM WAV；增加这些格式或流式音频能力时须重新评估该设置。
- Gradle 堆上限 4 GB、Metaspace 1 GB、最多两个 worker，限制云端并发内存占用。

2026-10-26 调研构建：原配置约 37.89 MB，拆包 / 分离符号后 28.87 MB，再裁剪编解码器后 27.14 MB。这些是当时版本的实际 APK 文件大小，不作为未来版本保证值；图片尚未转换或压缩。正式交付以本次构建清单和设备验证为准。

## GitHub Actions

[Android 工作流](../../.github/workflows/android-build.yml) 在 main 推送、PR 和手动运行时执行。统一客户端检查和原生构建独立运行，方便检查失败时仍下载构建诊断；发布 job 同时依赖二者成功，检查失败不会上传。普通推送 / PR 只构建内测包。

推送 / PR 默认构建 preview，不读取正式签名。云端 preview 使用 runner 临时 debug key，只用于构建核验，不能保证覆盖本机安装包或前次云端包。手动运行可选择 release，并在仓库 Actions Secrets 设置：

| Secret | 内容 |
| --- | --- |
| ANDROID_KEYSTORE_BASE64 | 长期 keystore 文件的完整 Base64 编码 |
| ANDROID_STORE_PASSWORD | key.properties 中的 storePassword |
| ANDROID_KEY_ALIAS | key.properties 中的 keyAlias |
| ANDROID_KEY_PASSWORD | key.properties 中的 keyPassword |

不要把签名、密码或 API Key 放入仓库、聊天、日志或构建 artifact。云端正式包应使用与本机相同的长期 keystore。工作流用运行编号作为构建号；首次配置时核对它高于已分发版本，重跑同一 run 不视为新版本。

构建成功后在 Actions 页面下载 artifact，保留 30 天；长期归档需另行备份。手动运行时 signing 选 release 才能发布。

## 蒲公英发布

在同一仓库的 Actions Secrets 中配置 `PGYER_API_KEY`，值为蒲公英账户 API Key，不需要账号 ID 或 appKey。可选配置 `PGYER_INSTALL_PASSWORD`：有值时按密码安装发布，没有时为公开链接安装。安装密码和 API Key 都只通过发布步骤的环境变量读取，不写入应用、日志或 artifact。

工作流合入默认分支后，打开仓库 Actions → Android build → Run workflow，signing 选择 release，并勾选 publish_to_pgyer。完整客户端检查与签名构建均通过后，自动下载本次正式包、上传并等待蒲公英完成发布。成功后的 job Summary 包含下载链接和二维码，另行归档 `pgyer-release.json`；未勾选只构建，不上传。

[发布脚本](../../tool/publish-pgyer.mjs) 使用三步流程：获取临时上传凭证、上传 APK、每 5 秒查询最终发布状态，最多等待 5 分钟。上传前校验正式包清单、字节数与 SHA-256，拒绝 preview 包和不匹配文件；只向蒲公英上传 APK，不上传符号或签名文件。返回发布成功后再次核对包名、平台、版本和大小，才输出下载地址。安装密码不会出现在成功记录中。

token / 上传请求不自动重试，避免网络响应丢失时重复发布；状态超时或网络失败后先到蒲公英后台确认结果，再决定是否重跑。手动发布不会被普通推送取消，并以独立并发组串行发布，避免两个版本同时更新下载入口。

发布逻辑的本地模拟回归由 `node --test tool/publish-pgyer.test.mjs` 执行，覆盖成功、等待、拒绝、超时、文件篡改、错误包身份和凭证不回显；已加入统一检查。模拟回归不会调用真实蒲公英接口，真实联调以工作流记录为准。

## 安装与验证边界

原有安装包使用 debug 签名。正式 key 签名的同包名 APK 无法直接覆盖它；不要直接卸载旧应用，应先安排本地记录的备份 / 迁移。本机 preview 使用原 debug key 时可尝试覆盖，但仍需核对构建号和设备安装结果。构建脚本不自动安装、卸载或清理手机数据。

构建不证明真机行为。分发前验证冷启动、三主题音效 / 试听、后台通知音、通知点击、四种桌面组件、MMKV 数据恢复及同签名版本覆盖升级。统一客户端检查入口与原生验证步骤见 [测试规范](testing.md)。

2026-10-26 初始构建验证：统一入口成功生成 release / preview 两份约 27.14 MB 的 APK，包内 versionCode 为 2001；正式包通过 apksigner 校验且证书与新长期 keystore 一致，preview 证书与原本机 debug APK 一致。已检查仅含 arm64 库、已排除 Xiph 库、SHA-256 与构建清单一致，Dart 符号及 R8 mapping 已归档；缺失签名和覆盖已有密钥均被拒绝。未安装 / 卸载手机应用。

初始统一检查的文档、格式及静态分析通过，完整测试曾停于 macOS objective_c hook 链接。主机后续已切到可用的 Xcode 27.1，本轮恢复完整测试并复现历史 7 项失败；核对产品规范后只修订过期测试：分秒滚轮 / 自动保存、必填常用项与滚动定位、日期卡片进入明细、最近一年语义文案。相关三文件 41 项回归通过，未修改产品 UI 或业务代码。当前全量门禁与云端联调状态见 [已知缺口](../known-gaps.md)。

2026-10-26 云端真实联调完成：工作流已通过 PR #1 合入 main，手动运行 #4（40262613858）的客户端检查、正式签名构建和蒲公英发布全部成功。Android versionCode 为 2004，APK 27,135,431 字节（约 27.14 MB，蒲公英下载页以二进制口径显示约 25.9 MB）；包内仅含 arm64 原生库、没有 Xiph 编解码器，云端 APK 的证书与本机长期密钥一致，SHA-256 与发布回执一致。蒲公英下载页已确认版本 1.0.0 和安装入口；当前为公开链接安装，未配置安装密码。云端已归档本次 APK / 符号 / mapping / 清单 / 发布回执，下载入口可从该运行 Summary 获取；用户手机尚未安装或卸载。
