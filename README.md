# 一刻 · Yike

> 本项目已完成从原型 Demo 到 Flutter 的首轮迁移，迁移成果已获用户认可，当前进入以 Flutter 为主的开发与体验打磨阶段。日常开发依据本仓库的产品、交互、动效文档和 Flutter 工程，默认无需阅读 PBWork 原型、Vue 源码或调用 ProtoBridge MCP。仅在用户明确要求原型迁移、固定证据核对或 DS 同步时进入对应专项；未明确的产品体验直接讨论确定。

一刻是本地使用的专注与习惯工具，面向工作、学习和日常习惯场景。打开即可开始专注，一次点击完成今天的习惯，再通过周月回顾查看时间与打卡的积累。

应用围绕三个页面组织：

- **专注**：番茄钟、正计时与计圈、倒计时。
- **打卡**：习惯创建、打卡、详情、归档与管理。
- **回顾**：周月统计、每日图形和日期明细。

机械、水位、日影三套主题共享业务与导航，外观可选择浅色、深色或跟随系统。产品仅在本机保存，不包含账号、云同步或社交功能。

## 当前实现

Flutter 工程已有上述页面、设置和启动页，以及三主题、导航和表单交互。已接入本地计时、历史结算、习惯与打卡、统计、偏好及快照恢复；业务动效已保留部分基础代码，尚未完成验证；已有初稿、历史验证边界和新对话接续顺序统一见 [动效与布局连续性实施计划](docs/reviews/2026-10-23-motion-implementation-plan.md)。完整移动视觉验收仍未完成。具体状态与待决事项见 [已知缺口](docs/known-gaps.md)。

## 运行

```bash
flutter pub get
flutter devices
flutter run -d <device-id>
```

需要 Flutter SDK，Dart 版本须满足 `pubspec.yaml` 中的 `^3.12.0`。iOS 使用 Xcode 与 CocoaPods。完整检查和设备验证见 [测试与视觉验证](docs/engineering/testing.md)。

## 文档

- [产品说明](docs/product/product.md)：定位、范围和页面职责。
- [逻辑与交互](docs/product/logic-and-interactions.md)：计时、习惯、保存恢复与统计规则。
- [UI 设计](docs/product/ui-design.md)：页面结构、三主题和可访问性。
- [动效规格](docs/product/motion.md)：触发、过程、中断、重播和减少动态效果。
- [文档索引](docs/README.md)：工程规范、当前缺口与历史评审。
- [协作与工作流](docs/workflow.md)：任务阅读、持续实施、决策边界和验证要求。
