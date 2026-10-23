---
name: proto-bridge-consumer
description: 仅在用户明确要求原型迁移或固定 Evidence 核对时，消费 Yike 的固定 ProtoBridge Handoff 并实现验证选定范围。普通 Flutter 开发不适用。
---

# ProtoBridge Consumer

仅在用户明确要求原型迁移或固定 Evidence 核对时使用；日常 Flutter 开发不因出现历史 Handoff 引用而触发。本 Skill 负责固定证据的读取与实现；通用阅读顺序、审批、修改边界和交付要求遵守 [协作与工作流](../../../docs/workflow.md)。

Evidence Region 用于定位与验收事实；它们不是 Widget 边界、ListView item 或文件边界。按 Screen 实施。reconstruction obligations 用于实施后复查，不规定编码顺序。

## 编辑前读取

1. 先读取资源 `proto-bridge://guides/handoff-consumer`，再调用 `inspect_evidence_workspace`，核对 Workspace、交付目标与所需 consumer capabilities，再调用 `read_handoff_index`。
2. 每个选中 Screen 调用一次 `read_screen_packet`。用 `canonicalBrief`、baseline structure/state，以及按 `regionId` / `caseId` 组织的 `implementationInventory`，理解主滚动归属、主 section、状态矩阵和固定业务数据。
3. 用 digest 分组的 `representativeBlobId` 直接查看每份不同 Screenshot。记录可见结构、响应式假设、覆盖的 Case，以及未解决的布局敏感值。
4. 编辑前调用 `inspect_target_readiness` 并解析组件/Token。非 baseline Case 使用 `read_case_delta`；仅在有明确未决问题时调用 `read_evidence_detail`。默认路径不要调用 `read_implementation_plan` 或 `read_implementation_tranche`；二者仅作诊断。
5. 查看相似页面以及真实的公共组件、Theme、路由 API，核对落点与状态归属；工程文档与公开代码优先于 adapter 回退规则。完成读取后按用户授权实施；仅在用户要求先评估或出现新的产品取舍时进入对应确认，已有批准持续有效。

## 实现所选范围

1. 区分页面 Variant、局部交互状态、导航、弹层，以及提交/刷新状态。显式覆盖每个选中 Evidence Case；不要只实现默认 Case。
2. 用 [公共组件](../../../docs/engineering/components.md) 和真实 Dart 构造函数，把 Evidence role/component 映射到目标 symbol，采用已有语义组件。
3. 用自然的 Flutter 组合表达滚动与层级；不要把每个 Evidence Region 映射成 builder 下标、类或文件。
4. 优先复用 Evidence/Source 的固定业务数据（key、文案、选项、默认值、序列），不要自行发明 mock。
5. 只实现所选 Evidence 支持的可观察行为。Evidence 缺失或冲突时，记录缺口并选择对目标工程扰动最小的本地行为；不要静默发明产品状态。

## 验证

1. 按 precondition → action → observable checkpoint 演练每个选中 Scenario。确认筛选、搜索、刷新、提交和导航状态可见且已接线，而不是空回调。
2. 按 [测试与视觉验证](../../../docs/engineering/testing.md) 执行原生检查，并按 Evidence viewport 在可用移动设备演练选中 Case。
3. 截图前进入指定状态并等待稳定；截图、场景重放与代码推理分别记录，不能互相替代。
4. Target adapter 可用时，用受限 `allowedPaths` 与 expected changed files 调用 `validate_target_changes`。
5. 实施后按需使用 `read_reconstruction_obligations` / Review 工具复查固定分母；不要把 obligation 顺序当成实施顺序。

报告与还原 Review 按 [工作流中的验证与交付](../../../docs/workflow.md#验证与交付) 执行。
