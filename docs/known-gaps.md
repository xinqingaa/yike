# 已知缺口与测量边界

本页列出具体问题和缺少的测量数据。问题记录包含复现条件、影响、下一步及验证方式；测量数据不足不等同于已经确认存在性能故障。

| 事项 | 边界与验证方式 |
| --- | --- |
| 真机性能基线 | 缺少可复用的全量真机 profile 对照数据；出现卡顿或启动问题时，按 [运行时](engineering/runtime.md#测量与预算) 记录设备、场景及 UI/raster 分位耗时，再决定优化 |
| 大量历史数据 | 缺少大规模历史数据的启动、序列化、查询和滚动基线；按 [存储](engineering/storage.md#版本与增长) 测量后再评估索引或拆分 |

系统通知送达、组件刷新预算、活动回收和异常终止恢复的限制分别由 [运行时](engineering/runtime.md)、[原生组件](engineering/system-surfaces.md) 和 [交互规则](product/logic-and-interactions.md#保存触发与恢复限制) 说明。
