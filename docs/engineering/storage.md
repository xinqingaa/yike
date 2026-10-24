# 本地存储

本文拥有存储接口、键白名单、快照与失败处理规范；产品恢复语义见 [逻辑与交互](../product/logic-and-interactions.md)。

只通过 `AppPrefs` 访问 MMKV。生产实现为 `MmkvAppPrefs`，由 `AppStartup` 等待初始化成功后 override `appPrefsProvider`。单元与 Widget 测试使用 `test/support/fake_app_prefs.dart`，原生集成测试单独验证真实 MMKV。生产实例为 `yike`，当前偏好 key：

- `theme_mode`：`light` | `dark` | `system`（一刻默认跟随系统）
- `theme_pack`：已注册的类型化主题包 ID
- `business_snapshot`：版本化业务快照，包含初始化日期、计时偏好、会话、周期、专注记录、习惯与打卡身份。由 `features/local_data` 负责组合序列化和单 key 保存；feature 只通过 AppPrefs，禁止直接 MMKV。

计时与习惯各自保留模型与规则；跨模块快照协调放在 local_data 模块。公开的 focus_models.dart / habit_models.dart 只导出模型和纯逻辑，避免反向导入页面。单一 LocalData Notifier 拥有业务事实，页面 Provider 只派生投影；tick 不写存储，阶段边界和用户操作才保存。

`app/local_data_boundary.dart` 处理读取阻断和保存失败重试；`storage/preference_writer.dart` 保留失败的外观写入。重置由 `app/reset_data.dart` 协调业务快照、外观、根导航、回顾选择和撤销提示，feature 不相互导入私有页面。业务快照为单 key 写入，外观两项独立保存；重置任一写入失败均显示未保存状态，重试当前结果。

存储接口使用 `PrefsEntry<T>` 绑定键与 Codec，键由 `PrefsKey` 枚举限定在白名单；`AppPrefs.read/write` 调用 Codec 完成类型转换。String、bool、int、double 和版本化 JSON 均经 Codec 保存为字符串。业务 Codec、模型和校验仍在所属 feature；storage 不导入 feature。

初始化错误使用 `PrefsOpenException` 区分存储不可用与文件损坏。读取不存在的键返回 null；键存在但无法解码、底层异常、保存和删除失败均抛出含键与操作的 `PrefsException`，不把错误当作首次使用。`VersionedJsonPrefsCodec` 使用 `{schemaVersion, data}` 对象封装。当前仅接受 schemaVersion 1，未知版本阻断，不自动清除或覆盖原数据。除第一阶段新增反馈偏好允许缺字段默认值以外，不提供其它旧实例或快照迁移；未来有实际升级需求再添加迁移。打开已有 MMKV 文件前检查完整性，异常时拒绝打开，避免默认恢复策略丢弃数据。

不要为未提交表单、测试 fixture 或截图专用状态创建生产存储。需要新 key 时先改本文白名单，再改 `AppPrefs`。

## 结果、重试与一致性

命令先在内存生效，保存结果单独反馈。bool 返回值若表示保存成功，调用方不能据此推断业务从未执行；重试保存同一最终快照，不重新调用创建、打卡或结算。新增接口应让无效动作、已接受结果与保存失败的区别可判断。

读取失败是阻断状态，不是空数据；重试读取不覆盖原始文件，只有明确确认重置才重新初始化。外观与业务的独立写入可能部分成功，未保存状态持续到全部待保存内容写入成功。动画反馈不改变这些保证。

## 版本与增长

JSON 的 schemaVersion 与业务实体身份都必须验证。真正需要发布升级时先定义旧版本 fixture、逐版本迁移、未知版本保护和失败恢复，再修改接受范围；不要把未知字段或损坏数据当作默认值静默覆盖。

同步快照适合当前数据规模。以大量专注历史与多年习惯记录测量启动、编码、写入和查询耗时，再决定拆分、索引或异步化。迁移后仍需验证会话与记录幂等、跨日归属和失败可恢复性。

## 诊断与验证

日志只记录操作、键、版本与错误类别，不输出习惯名称、完整快照或用户记录。FakeAppPrefs 用于类型/故障注入；原生 MMKV 重开与进程重启使用隔离实例，禁止破坏生产 yike 数据。测试替身不能证明磁盘可靠性，验证入口见 [测试](testing.md#原生存储验证)。

## 第一阶段反馈偏好

业务快照 schemaVersion 1 的 TimingPreferences 保留 `sound` 和 `haptics` 为总开关，新增完整 `feedback` 对象，包含 `pomodoro`、`stopwatch`、`countdown`、`habits` 四个来源。三个计时来源各包含 sound / haptics / secondTick（bool）、beatMinutes（0 / 1 / 5 / 10 / 15）；打卡只包含 sound / haptics。

读旧快照（feedback 字段缺失）时，将 sound / haptics 复制到四个来源；旧 beatMinutes（缺省 5）迁到番茄、正计时；旧 secondTick（缺省 true）迁到倒计时。番茄和正计时新增 secondTick=false，倒计时新增 beatMinutes=0；总开关及原来实际生效的选择不被重置。新的 feedback 对象一旦存在就要求四组字段完整、类型及取值合法，null 或部分损坏仍阻断读取并保留文件，不回退默认。保留的旧字段如存在也须合法。

写入总是写完整 feedback 对象，不再写顶层 secondTick / beatMinutes，不增加存储 key，不改变版本号、会话身份或暂停恢复策略。关闭总开关不修改各来源值；测试须覆盖旧 fixture、坏值拒绝、独立配置及重开保持。

## 第二阶段秒级格式目标（已确认，待实施）

当前代码仍为版本 1。第二阶段计划在同一 `business_snapshot` key 下直接使用 schemaVersion 2，偏好专注 / 短休 / 长休统一为明确秒字段，详见 [统一时长规则](../plan/duration-rules.md#数据格式与旧数据)。用户明确无需旧数据兼容，可自行卸载或明确重置，因此不实现版本 1 迁移；旧版本 / 未知版本 / 损坏数据继续阻断读取，保留原数据，不自动覆盖。新番茄会话支持整秒目标，范围按阶段校验，不保留旧整分钟限制。倒计时会话除实际目标外保存开始时的图形量程，重开恢复同一比例，不从最新常用项反推；正计时会话支持 3599 秒上限完成态与计圈读取。实施时更新对应合法 fixture 与版本断言，不把旧数据读取阻断当作初始化或迁移成功。
