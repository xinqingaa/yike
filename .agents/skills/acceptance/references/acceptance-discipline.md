# Acceptance Discipline

完成 Target 实现和原生验证后、调用 `summarize_reconstruction_review` 前，必须对固定 Handoff 选中范围执行本纪律。它约束 Consumer Review，不改变 Evidence，也不把 Consumer 自报提升为独立 Runtime 或最终视觉验收。

## 范围

- 只验收 Handoff 选中的 Screen、Case、Variant 和 Scenario；不得把未选中的 loading、error、empty 或其它状态扩展为本次范围。
- 所有判断使用同一 Handoff 的固定 Snapshot、revision、Screenshot 和 Reconstruction Obligations。
- 按 Screen 和单一维度读取 `read_reconstruction_obligations`；obligation 只规定实施后复查分母，不规定编码顺序。

## 前置完整性

在报告任何匹配前确认：

- 每个选中 Screen 已读取 `read_screen_packet`；
- 每份不同 Screenshot 内容已用 digest group 的 `representativeBlobId` 调用 `read_evidence_screenshot`；
- baseline 无法解释的选中 Case 已读取 `read_case_delta`；
- Target 原生验证已运行，适用时已调用 `validate_target_changes`；
- 状态矩阵、固定业务数据、keyed collection、组件和 Token resolver 结果已记录。

不能用 `canonicalBrief`、Blob metadata、代码注释或相似 Variant 代替真实 Screenshot。

## 五维判据

### Structure

核对主滚动所有者、成员 section、语义层级、构图轴向和关键邻接关系。代码与固定 Evidence 可以支持结构语义判断；没有 Target 视觉结果时，不得把代码推理描述成像素级视觉验证。

### Components

`resolved` mapping 必须在本次 Target 变更的真实使用点采用。公共组件可以是正确实现选择，但只要最终可见结果与 Screenshot 不同，仍记录为 `deviation` 并说明 Target 规范依据、差异和影响。`candidate`、`stale`、`conflict`、`unresolved`、`unsupported` 或 `pending` 不能报告为匹配；`pending` 必须保持 `unverified`，说明 Target 待实现的理由。

### Tokens

Evidence token 必须通过 resolver 映射并在当前实现中真实使用。相似名称、相近颜色或硬编码等价值不是精确命中，应记录为 `deviation`。缺少可靠 mapping 时保持 `unverified`，不能为了填满映射而发明 Target token。

### States

只实现和复查选中 Case 的 Variant/state。Evidence 已明确证明为完整的数值、时间戳、文案、选项、selected/default 值、key 和 ID 必须精确复用；Evidence 为 partial、unknown 或 conflict 时禁止猜测补全，并按影响保持 `unverified` 或报告 blocker。

### Interactions

逐个复查选中 Scenario checkpoint、导航参数、表单校验和状态变化。只有实际执行的测试或可核对的目标代码才能作为依据；不能由 Consumer 自填预期结果冒充已重放验证。

## Observation 状态

- `matched`：有可靠 evidence 支持当前实现符合 obligation expected。
- `deviation`：已知实现不同；必须提供 evidence，并说明原因和影响。
- `unverified`：缺少 resolver、测试、设备、Runtime 或人工依据；必须说明无法验证的原因。
- `not-applicable`：obligation 对当前选中 Case 不适用；必须说明理由。

`unverified` 是诚实状态，不是逃避路径。空 observations 只能产生 partial Review；禁止的是用它掩盖未验证范围、无依据的 `matched`、无原因的 `deviation` / `unverified`，以及把 partial Review 描述成完成。

## Summary 与人工复查

调用 `summarize_reconstruction_review` 时，为每个适用 obligation 提交且只提交一个 observation。分别报告：

1. Review completeness：Case、Screenshot、Scenario 和 obligation observation 是否完整；
2. Fidelity findings：matched、deviation、unverified、not-applicable；
3. `validationAuthority: consumer-reported-review`。

报告末尾生成针对本次范围的 `Human Verification Checklist`。按 Screen 使用实际 `screenId`、`caseId` 和 `representativeBlobId` 定位；只有 Delivery manifest 明确提供路径时才写 Screenshot 文件名。检查项来自本次 deviations、unverified、固定状态数据和需要目视的视觉细节，不得使用与本次原型无关的硬编码模板。

Consumer 可以交付 partial Review，但不得声称“还原已验收通过”。最终视觉接受仍由人或未来具有独立 authority 的 Runtime 完成。
