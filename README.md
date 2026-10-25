# 一刻 · Yike

> 本项目已完成从原型 Demo 到 Flutter 的首轮迁移，迁移成果已获用户认可，当前进入以 Flutter 为主的开发与体验打磨阶段。日常开发依据本仓库的产品、交互、动效文档和 Flutter 工程，默认无需阅读 PBWork 原型、Vue 源码或调用 ProtoBridge MCP。仅在用户明确要求原型迁移、固定证据核对或 DS 同步时进入对应专项；未明确的产品体验直接讨论确定。

一刻是本地使用的专注与习惯工具，面向工作、学习和日常习惯场景。打开即可开始专注，一次点击完成今天的习惯，再通过周月回顾查看时间与打卡的积累。

应用围绕三个页面组织：

- **专注**：番茄钟、正计时与计圈、倒计时。
- **打卡**：习惯创建、打卡、详情、归档与管理。
- **回顾**：周月统计、每日图形和日期明细。

机械、水位、日影三套主题共享业务与导航，外观可选择浅色、深色或跟随系统。产品仅在本机保存，不包含账号、云同步或社交功能。

## 当前实现

Flutter 已接入计时与结算、习惯打卡、周月回顾、本地快照、三主题和设置。第一、二阶段已完成并获用户真机验收：声音与触感、独立设置与总开关、秒级时长、表盘调时及量程、正计时 59:59 上限；验收后补充常用项规则、设置直达弹层与完成音试听。

阶段 1 至 5 已完成并获用户验收，临时验收脚本与专用截图已清理。当前包括正计时右侧控制面板、计圈飞入、回顾筛选与数据卡、习惯查看和独立统计页。[六阶段计划](docs/plan/README.md) 保留索引与六阶段文档；第五阶段三模式并行与前后台提醒已接入，2026-10-25 已完成并获用户验收，包含最终 UI 修订与拖动条，临时材料已清理。第六阶段已接入 iOS / Android 桌面组件、iOS 锁屏组件、汇总实时活动与动态岛，工程检查及相关回归已完成，整体真机验收待进行。通知、全量视觉与真机性能仍有未覆盖项，历史门禁问题见 [已知缺口](docs/known-gaps.md)。

## 运行

```bash
flutter pub get
flutter devices
flutter run -d <device-id>
```

需要 Flutter SDK，Dart 版本须满足 `pubspec.yaml` 中的 `^3.12.0`。iOS 使用 Xcode 与 CocoaPods。完整检查和设备验证见 [测试与视觉验证](docs/engineering/testing.md)。

iOS 原生构建会调用 PATH 中的 CMake。换设备时下载官方 macOS 通用包 4.4.4，核对 SHA-256 后解压到用户目录，再把最后一行写入该设备的 shell 配置（如 `~/.zshrc`）。新开终端后运行。不要再安装第二份。

```bash
mkdir -p "$HOME/.local/opt"
curl -fL -o /tmp/cmake-4.4.4-macos-universal.tar.gz \
  https://github.com/Kitware/CMake/releases/download/v4.4.4/cmake-4.4.4-macos-universal.tar.gz
echo "4b7b73704b1db9b374e5c9ab8e17ac6148b817b6396ee75cd94a852cbac9d305  /tmp/cmake-4.4.4-macos-universal.tar.gz" | shasum -a 256 -c -
tar -xzf /tmp/cmake-4.4.4-macos-universal.tar.gz -C "$HOME/.local/opt"
export PATH="$HOME/.local/opt/cmake-4.4.4-macos-universal/CMake.app/Contents/bin:$PATH"
```

校验值来自该版本发布文件 `cmake-4.4.4-SHA-256.txt`。解压后的可执行文件是 `~/.local/opt/cmake-4.4.4-macos-universal/CMake.app/Contents/bin/cmake`。Android 构建使用 Android SDK 自带的 CMake 3.22.1，不读取这条 PATH。

## 文档

- [产品说明](docs/product/product.md)：定位、范围和页面职责。
- [逻辑与交互](docs/product/logic-and-interactions.md)：计时、习惯、保存恢复与统计规则。
- [UI 设计](docs/product/ui-design.md)：页面结构、三主题和可访问性。
- [动效规格](docs/product/motion.md)：触发、过程、中断、重播和减少动态效果。
- [文档索引](docs/README.md)：工程规范、当前缺口与历史评审。
- [协作与工作流](docs/workflow.md)：任务阅读、持续实施、决策边界和验证要求。
