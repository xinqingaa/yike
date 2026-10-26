# Android 构建与发布

发布目标为 arm64 Android 手机，应用 ID 为 `com.protobridge.yike`。本地与 CI 共用 [构建入口](../../tool/build-android.mjs)，固定 release 构建模式、ABI 拆包及 Dart 调试符号分离。工具版本和升级位置见 [开发环境](development-environment.md)。

## 云端手动打包

进入 [Android build · 打包与蒲公英发布](https://github.com/xinqingaa/yike/actions/workflows/android-build.yml)，点击 **Run workflow**，选择 `main` 与操作后运行：

| 操作 | 签名 | 结果 |
| --- | --- | --- |
| 发布到蒲公英（默认） | 长期 release 签名 | 完整检查、构建，通过后上传并确认发布 |
| 只构建正式 APK | 长期 release 签名 | 完整检查、构建，不上传 |
| 只构建内测 APK | runner 临时 debug 签名 | 完整检查、构建，不上传，仅供构建核验 |

这是单选下拉框，不需要另外选择签名或勾选发布。运行使用所选分支的已推送代码，不包含本机未提交或未推送的修改。重跑旧运行仍使用旧提交；要构建新代码，从 main 新建运行。

[工作流配置](../../.github/workflows/android-build.yml) 的触发规则：

| 触发 | 执行内容 |
| --- | --- |
| main push / PR 创建或更新 | 完整客户端检查；全部变更为 Markdown 时只检查文档、不安装 Flutter |
| 手动运行 | 始终完整检查并构建 APK；选择发布时才上传 |
| 本地 commit、没有 PR 的普通分支 push | 不触发此工作流 |

一次 push 包含多个 commit 时，按这次推送后的代码检查一次，不逐个 commit 构建。PR 更新可能独立触发对应检查。普通推送不会打包或更新蒲公英；手动检查与构建并行，发布须等待二者成功。连续推送会取消同组旧自动检查，手动运行不被自动推送取消，蒲公英发布独立串行。

## Secrets 与长期签名

仓库 Settings → Secrets and variables → Actions 中配置 Repository secrets：

| Secret | 内容 | 使用场景 |
| --- | --- | --- |
| ANDROID_KEYSTORE_BASE64 | 原长期 keystore 文件完整的 Base64 编码 | 正式构建 |
| ANDROID_STORE_PASSWORD | `key.properties` 的 storePassword | 正式构建 |
| ANDROID_KEY_ALIAS | `key.properties` 的 keyAlias | 正式构建 |
| ANDROID_KEY_PASSWORD | `key.properties` 的 keyPassword | 正式构建 |
| PGYER_API_KEY | 蒲公英账户 API Key，不是账户 ID 或 appKey | 蒲公英发布 |
| PGYER_INSTALL_PASSWORD | 可选安装密码；未设置则为公开链接安装 | 蒲公英发布 |

Secrets 仅在相应步骤通过环境变量读取，不写入应用、日志或 artifact。正式构建临时还原 keystore，结束时清除；preview 不读取正式签名。更新凭证在 GitHub Secrets 中替换，不能通过运行日志读回验证。

没有签名时，首次在本机运行 `node tool/create-android-signing.mjs`。生成器使用 JDK keytool，默认写入用户目录 `.config/yike/signing/yike-release.jks` 和 `key.properties`，设置私有权限；任意文件已存在时拒绝覆盖，不输出密码。安全备份两个文件，后续版本与新电脑沿用原密钥，不因换设备重新生成。

## 本地构建与版本

```bash
# 正式签名构建
node tool/build-android.mjs

# 使用本机 debug key 的 release 模式内测包
node tool/build-android.mjs --preview

# 显式指定版本与递增构建号，示例值须按实际分发版本调整
node tool/build-android.mjs --build-name 1.0.1 --build-number 20
```

签名文件按优先级选择：`YIKE_ANDROID_KEY_PROPERTIES`、`android/key.properties`、用户目录 `.config/yike/signing/key.properties`。也可设置 `YIKE_ANDROID_STORE_FILE`、`YIKE_ANDROID_STORE_PASSWORD`、`YIKE_ANDROID_KEY_ALIAS`、`YIKE_ANDROID_KEY_PASSWORD`，环境变量字段优先。相对 storeFile 以 `android/` 为基准；正式签名缺失时失败，不自动退回 debug key。

应用版本默认读取 `pubspec.yaml` 的 `version`；云端使用 `GITHUB_RUN_NUMBER` 作为 Flutter 构建号。一次推送检查也会占用运行编号，因此发布号有间隔是正常的。ABI 拆包会调整 APK 内的 versionCode，清单 `flutterBuildNumber` 仅记录传给 Flutter 的原始值；更新前核对 APK 的实际 versionCode 高于已分发包。不要随意切换拆包规则或重置运行编号，重跑同一 run 不视为新版本。

## 产物与蒲公英

本地产物位于 `build/releases/android/release/` 或 `preview/`，包含版本化 APK、`manifest.json`（大小、SHA-256、签名模式、ABI）及 `symbols/` 下的 Dart 符号、存在时的 R8 mapping。构建入口使用 `flutter pub get --enforce-lockfile`，不手动修改生成的插件文件。

云端在运行页面的 Artifacts 下载产物，保留 30 天。已分发版本需要自行长期保留 APK、清单和符号，用于回溯及崩溃还原；keystore 不在 artifact 中。Gradle 缓存按构建配置、wrapper 与 pubspec.lock 区分，首次构建仍需下载和转换依赖。上传 / 下载 Action 固定提交 SHA，版本与内部运行时见 [环境说明](development-environment.md#环境版本与配置位置)。

[蒲公英脚本](../../tool/publish-pgyer.mjs) 先校验正式包清单、大小和 SHA-256，再获取临时凭证、上传 APK、每 5 秒查询最终状态，最多等待 5 分钟。拒绝 preview 包或不匹配文件，只上传 APK，不上传符号及密钥。返回成功并核对包名、平台、版本及大小后，Summary 提供下载链接和二维码，并归档 `pgyer-release.json`。

每次“发布到蒲公英”都会构建本次正式包；发布操作不提供单独的历史产物选择。检查通过不等于发布，上传请求成功也不等于最终发布成功。

## 体积优化与安装

- 只为 arm64 构建，不适用于 32 位手机和 x86 模拟器。
- 分离 Dart 调试符号，使用 release 默认 R8 / 资源缩减与图标字体裁剪。
- `android/gradle.properties` 的 `NO_XIPH_LIBS=true` 裁剪 flutter_soloud 的 Opus / Ogg / Vorbis / FLAC；九段主题音效采用 PCM WAV，增加这些格式或流式音频时重新评估。
- Gradle 堆上限 4 GB、Metaspace 1 GB、最多两个 worker。

体积参考值为 APK 约 27.14 MB；大小随版本变化，以清单为准，图片尚未另做格式转换或压缩。蒲公英以二进制口径显示时约 25.9 MB。

覆盖更新要求同包名、同长期签名及更高 versionCode。原 debug 包无法直接被正式签名包覆盖；先安排数据备份 / 迁移，不自动卸载或清理手机。云端 preview 使用临时 debug key，不能保证覆盖本机或前次云端包。日常分发使用长期正式签名。

构建验证与装机行为分开；变更涉及音效、通知、小部件、存储或签名时，按 [测试规范](testing.md) 验证受影响行为和覆盖更新。

## 故障处理

| 现象 | 检查与处理 |
| --- | --- |
| Client checks 失败 | 展开实际失败步骤；纯文档检查可在本机运行 `node tool/check-docs.mjs`，完整检查运行 `node tool/verify.mjs` |
| 正式签名恢复 / 构建失败 | 核对四项签名 Secrets、Base64 完整性和密钥身份；不要把值贴进聊天或日志 |
| SDK / NDK / CMake 或插件构建失败 | 比对 [环境配置](development-environment.md#环境版本与配置位置)，检查失败日志，不直接混用本机升级后的工具链 |
| 上传失败或查询超时 | 先到蒲公英后台核对是否已经发布，再决定重试；token / 上传不自动重试，避免重复发布 |
| 无法覆盖安装 | 核对包名、证书及 APK 实际 versionCode；不通过卸载规避数据问题 |
| 修改配置后重跑仍旧失败 | 从 main 新建 Run workflow，旧运行重跑不会更新其代码版本 |

本地发布逻辑模拟回归为 `node --test tool/publish-pgyer.test.mjs`，已纳入统一检查，不调用真实蒲公英 API。触发真实发布仍需用户明确授权。
