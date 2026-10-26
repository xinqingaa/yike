# Yike Agent 入口

本仓库是一刻（Yike）的 Flutter 应用。产品行为和工程规则在本仓库独立维护；日常任务不要求阅读 PBWork 原型、Vue 源码或调用 ProtoBridge MCP。

## 阅读与文档维护

先读 [README](README.md)、[协作与工作流](docs/workflow.md)，按 [文档索引](docs/README.md) 阅读任务相关规范。代码修改遵守 [工程架构](docs/engineering/architecture.md)；环境准备见 [开发环境](docs/engineering/development-environment.md)，打包发布见 [Android 构建与发布](docs/engineering/android-build.md)，当前问题见 [已知缺口](docs/known-gaps.md)。

README 是项目、运行和打包发布入口；AGENTS 是 Agent 协作入口；产品及工程主文档统一放在 `docs/`。修改功能时直接更新所属主文档，连贯说明产品能力、操作结果或工程机制；必要的设计理由写在相关规则旁，不另建阶段计划、决策归档或验收流水。

原型迁移、固定证据核对与 DS 同步仅在用户明确要求时启用对应专项流程。

## Git 授权

未经用户明确允许，不执行 Git commit、push、远程合并或发布。用户批准计划、要求开始实施或完成修复，不代表授权提交和推送；默认保留工作区改动供用户检查。

分支创建、删除和远程引用变更须符合用户明确授权的范围。分支清理授权不包含提交或推送代码。保留用户无关改动，不自动重置、强制推送或删除未确认的工作。
