---
name: proto-bridge-consumer
description: 在本 Flutter 应用中消费固定 ProtoBridge Handoff，并实现、导航、测试与目视核验所选 Evidence 范围。用于面向 yike 的 ProtoBridge Evidence 交付任务。
---

# ProtoBridge Consumer

当任务提供固定 Workspace、Handoff、Bundle、Snapshot 或 Evidence 范围时，使用本流程。保持 Source Evidence 与目标工程决策分离：Evidence 决定可观察结果，本工程的文档与代码决定实现边界。

Evidence Region 用于定位与验收事实；它们不是 Widget 边界、ListView item 或文件边界。按 Screen 实施。reconstruction obligations 用于实施后复查，不规定编码顺序。

MCP 已由 `tool/mcp.mjs` 绑定到本工程；不要修改 proto-bridge producer，也不要把 Target 查询结果当作 Source Evidence。

## 编辑前读取

1. 阅读 `AGENTS.md`、`README.md` 以及 `docs/` 下相关文件。
2. 先读取资源 `proto-bridge://guides/handoff-consumer`，再调用 `inspect_evidence_workspace`，核对 Workspace 与所需 consumer capabilities，再调用 `read_handoff_index`。编辑前原样报告全部 `mandatoryRisks`。不得用 active/latest 替换固定引用。
3. 每个选中 Screen 调用一次 `read_screen_packet`。用 `canonicalBrief`、baseline structure/state，以及按 `regionId` / `caseId` 组织的 `implementationInventory`，理解主滚动归属、主 section、状态矩阵和固定业务数据。
4. 用 digest 分组的 `representativeBlobId` 直接查看每份不同 Screenshot。记录可见结构、响应式假设、覆盖的 Case，以及未解决的布局敏感值。
5. 编辑前调用 `inspect_target_readiness` 并解析组件/Token。非 baseline Case 使用 `read_case_delta`；仅在有明确未决问题时调用 `read_evidence_detail`。默认路径不要调用 `read_implementation_plan` 或 `read_implementation_tranche`；二者仅作诊断。
6. 每个 Screen 在编辑前用简短散文写出 Evidence 理解摘要：主结构与滚动边界、拟用的组件/Token 落点、状态与交互覆盖，并附实现计划。这是给人纠偏的检查点，不是清单、评分表或验收分母。
7. 在决定文件位置或状态归属前，先查看相似页面以及真实的公共组件、Theme、路由 API。真实工程文档与公开代码优先于 adapter 回退规则。
8. 输出摘要与实现计划后必须暂停，等待用户明确批准。未获批准前不得修改本工程代码，也不得执行会改变目标工程状态的命令。

## 实现所选范围

仅在用户明确批准后进入本阶段。

1. 区分页面 Variant、局部交互状态、导航、弹层，以及提交/刷新状态。显式覆盖每个选中 Evidence Case；不要只实现默认 Case。
2. 用 `docs/components.md` 和真实 Dart 构造函数，把 Evidence role/component 映射到目标 symbol。目标工程已有语义组件时，不要用外观相近的通用 widget 静默替代。resolver 返回 `pending`（Target 待实现）的组件/Token 必须披露，不得自行替换实现。
3. 遵守本工程的架构、Theme、路由和共享弹层边界。业务代码放 `lib/features/<feature>/`，路由放 `lib/router/`，Token 放 `lib/theme/`，可复用 UI 放 `lib/common/`。用自然的 Flutter 组合表达滚动与层级；不要把每个 Evidence Region 映射成 builder 下标、类或文件。
4. 优先复用 Evidence/Source 的固定业务数据（key、文案、选项、默认值、序列），不要自行发明 mock。
5. 只实现所选 Evidence 支持的可观察行为。Evidence 缺失或冲突时，记录缺口并选择对目标工程扰动最小的本地行为；不要静默发明产品状态。

## 验证

1. 按 precondition → action → observable checkpoint 演练每个选中 Scenario。确认筛选、搜索、刷新、提交和导航状态可见且已接线，而不是空回调。
2. 在目标根目录运行 `flutter analyze` 与 `flutter test`；有需要时可加更窄的 feature 测试。
3. 有模拟器或真机时，按 Evidence viewport（本仓库 iPhone 14 Evidence 为 `390x844`）运行应用，进入每个选中 Case，状态稳定后截图。设备命令见 `docs/testing.md`。
4. Target adapter 可用时，用受限 `allowedPaths` 与 expected changed files 调用 `validate_target_changes`。
5. 实施后按需使用 `read_reconstruction_obligations` / Review 工具复查固定分母；不要把 obligation 顺序当成实施顺序。

## 报告

报告固定引用与 revision、原始 mandatory risks、修改文件、原生检查/测试、视觉验证是否可用、Target validation、已知 Evidence 偏差，以及剩余风险。
