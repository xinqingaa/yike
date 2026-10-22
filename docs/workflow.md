# 协作与工作流

本页统一维护一刻的开发协作流程。产品规则、工程规范和当前状态分别由对应文档负责，避免在 README、AGENTS 和 Skills 中维护多份通用流程。

## 开始工作

先读根 [README](../README.md)、[文档索引](README.md) 和 [已知缺口](known-gaps.md)，确认产品定位与当前实现。产品任务再读 [产品说明](product.md)、[逻辑与交互](logic-and-interactions.md) 和 [UI 与动效](ui-design.md)；代码修改按 [工程架构](architecture.md) 查阅相关组件、主题、资源和路由规范。

先检查工作区已有改动。修改只覆盖用户授权的范围，保留无关的未提交内容。本仓库只维护一刻应用，不修改 ProtoBridge producer，不复制 Evidence Store 到目标工程。

## 评估、批准与实施

用户要求先评估时，只读核对现状，说明问题、方案、预计文件和验证方式，等待明确批准后再修改。

收到新的固定 PBWork Handoff 时，先按 Consumer Skill 读取 Evidence 和目标上下文。编辑前原样报告 `mandatoryRisks`，按 Screen 用简短散文说明结构与滚动边界、组件与 Token 落点、状态与交互覆盖、预计修改文件、验证方式和剩余风险，然后暂停等待明确批准。未获批准前不修改本工程，也不执行改变目标工程状态的命令。

批准后完成约定范围内的实施与检查；已有批准持续有效，不为同一范围的后续步骤重复请求确认。遇到新的产品取舍或超出授权的修改时，先完成不依赖该决定的工作，再说明待决内容。普通文档维护和不带固定 Handoff 的工程任务按用户给定范围执行，无需套用 Screen 交付流程。

## 文档、Evidence 与代码

产品要求直接读取本地文件，不通过 MCP 获取。三份产品文档承接 2026-10-16 已批准基线，于 2026-10-22 按产品、逻辑、UI 职责整理；后续修改随本仓库版本维护。

- 产品文档定义应用应有的行为；当前代码和已知缺口用于判断实际完成程度。
- 固定 ProtoBridge Evidence 决定源页面已观测的结构、文案、状态、交互与构图。读取时保留固定 Workspace、Handoff、Bundle、Snapshot 和 revision，不以 Producer 当前文件或 active/latest 替换。
- 本工程规范与公开代码决定 Flutter 的组件、Theme、路由、状态和存储落点。Target adapter 只提供目标上下文，不能覆盖 Screenshot、Fragment、Case 或 revision。

文档版本不自动等于 Evidence 版本。发现冲突时，在 [已知缺口](known-gaps.md) 记录双方来源、当前行为、影响和待决事项，不静默改写任何一方。设计中的动效意图也不能宣称为已采集的过程。历史固定交付引用与 receipt 保留在 [评审记录](README.md#协作与状态)。

## 任务 Skill

| 任务 | 读取入口 |
| --- | --- |
| 固定 Evidence 的页面实现 | [ProtoBridge Consumer](../.agents/skills/proto-bridge-consumer/SKILL.md) |
| 不带 Handoff 的 Design System 同步 | [DS Target Sync](../.agents/skills/proto-bridge-ds-target-sync/SKILL.md) |
| 实现完成后的还原 Review | [Acceptance](../.agents/skills/acceptance/SKILL.md) |

Skills 维护各自的专用操作和协议细节；通用协作规则以本页为准。组件或 Token 的 `pending` 必须披露，不得当作 resolved 或用外观相似实现静默替代。还原验收按结构、组件、Token、状态与交互五个维度复查，不能用自报结果代替最终视觉接受。

## MCP 与交付目标

`.cursor/mcp.json`、`.codex/config.toml` 和 `.mcp.json` 统一指向 `tool/mcp.mjs`。该入口从 `.pb-scaffold.json` 读取 Producer 路径和工作区配置；Codex 需 trust 项目目录才能加载项目级配置。

固定 Evidence 任务调用 `inspect_evidence_workspace`，确认 `deliveryTargetRoot` 指向本工程。不一致时停止该交付并报告。也可在工程根目录只读检查绑定：

```bash
node tool/target.mjs --check
```

需要切换 PBWork 的交付目标时，使用 `node tool/target.mjs --bind` 更新绑定，再重启相关 Producer/MCP 客户端并重新生成交付提示词；这会改变工作区交付配置，不能只改提示词里的路径。Producer 的实际根目录以 `.pb-scaffold.json` 的 `protoBridgeRoot` 相对本工程解析，避免硬编码另一台机器的路径。

## 验证与交付

执行 [测试与视觉验证](testing.md) 中的必要检查。代码和映射可定位、DS 同步通过、场景测试通过、移动视觉接受是不同结果，分别报告。固定 Evidence 实施后，适用时用受限 `allowedPaths` 和预期文件调用 `validate_target_changes`，再进入 Acceptance Review。

交付时说明修改文件、验证结果、当前偏差和剩余风险。固定 Evidence 任务还须包含固定引用与 revision、原始 `mandatoryRisks`、状态和交互覆盖、Target validation、视觉验证是否执行及 Review 完整度；未执行或未完成的部分明确保留。普通文档任务报告引用和内容核查结果，不补造 Evidence 或视觉结论。

产品要求变化更新产品、逻辑或 UI 文档；工程边界变化更新所属规范；当前缺口的解决和新待决事项更新已知缺口。历史评审保留当时的范围与结果，不能将旧报告当作当前全量验收结论。
