---
name: acceptance
description: 仅在用户明确要求固定 ProtoBridge Evidence 还原验收时，执行结构、组件、Token、状态与交互五维复查；普通 Flutter 功能与动效验收不适用。
---

# Acceptance

本 Skill 仅在用户明确要求固定 Evidence 还原验收时使用，只负责触发 Target 还原验收，不复制第二套消费流程或验收规则。通用协作与交付要求见 [协作与工作流](../../../docs/workflow.md)。

## 使用方式

1. 完成 Target 实现和原生验证后、调用 `summarize_reconstruction_review` 前应用本 Skill。
2. 完整读取 `references/acceptance-discipline.md`；它是验收纪律的唯一完整规则源。
3. 按固定 Handoff 选中范围读取五维 Reconstruction Obligations，形成 `matched`、`deviation`、`unverified` 或 `not-applicable` observations。
4. 调用 `summarize_reconstruction_review`，先报告 Review completeness，再报告 fidelity findings。
5. 基于 summary 生成人工验收清单；使用 Screen、Case 和 Screenshot blob ID 定位，不猜测文件名。

实施路径仍由 `proto-bridge-consumer` Skill 和 `proto-bridge://guides/handoff-consumer` 负责。本 Skill 不增加 Target Runtime authority，也不允许 Consumer 自报替代最终视觉验收。
