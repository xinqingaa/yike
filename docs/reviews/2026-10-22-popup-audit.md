# 第一层弹层自查

固定引用：workspace `pbwork-local`；handoff `handoff-2026-10-22t083440493-0b17323b`；bundle `bundle-2026-10-22t082823167-26f4539d`；snapshot `snapshot-2026-10-22t083354783-d240a8ad`。原始 mandatoryRisks：`[]`。

重新通过配置的 MCP stdio 读取 12 类代表截图及非 baseline 差量：专注的 abandon-confirm、switch-confirm、short-record、recovery、custom-duration；设置的 reset-confirm、configuration-open、record-threshold、threshold-custom；habit-editor/default；habit-detail/habit-records；review/day-detail。具体 case/blob/revision 见 layer-1 receipt。固定截图决定弹层类型，不能因名称含 confirm 就改成中心对话框。前三个确认中，只有短记录使用 Confirm，其余保留 Sheet。

本次修改 AppPop、DurationSheet、YikeSheetBody、CommonFlowSheetContent、CommonWheelPicker、CommonButton 及专注/设置/打卡弹层调用。容器、安全区域、键盘、拖拽、返回及过渡继续由 unified_popups 2.2.1 实现。调用方只组合内容，不实现弹层基础设施。读取了包 README、用法 skill、API §3/4/6/8/10/11 以及封装示例。

修正：正文/操作区分隔和间距；危险 Sheet 的描边胶囊按钮；滚轮三行可见；两步页脚固定、当前步骤为短条；FlowSheet 内页标题与返回；关闭后等待 dismissed；归档列表关闭完成再导航；Handle 留在 AppPop 内；补齐 FlowSheet 标题 Material 上下文，消除黄色下划线。常用项的清空移入固定操作区，避免短面板遮挡。

验证：flutter analyze 通过，flutter test 71 项通过；node tool/verify.mjs、ds-theme、ds-sync 通过（46/46 components、151/151 tokens、pending 0）。iPhone 14 390×844 原生查看时长 Sheet 与阈值 FlowSheet 两步、关闭和返回；Widget 测试覆盖关闭位移、草稿丢弃、重复值校验、320px 键盘下保存。未声称完成 199 Case 全量视觉验收。

局限：原型采集减少动效，无法以静态图证明动画时序；模拟器 debug 仍出现两条 Impeller inheritedOpacity 底层诊断；FlowSheet 头部控件在原生 AX 树中未列出，但屏幕可点、Widget 语义可找。保留原 repair 报告列出的整页字体/位置和性能限制。第二层业务尚未在本提交中实现。
