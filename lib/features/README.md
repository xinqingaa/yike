# Features

按业务模块组织：`focus/`、`habits/`、`review/`、`settings/`、`home/`、`launch/`。模块内页面放 `pages/`，模型放 `models/`，页面 Provider 放 `providers/`，私有图形放 `widgets/`；跨模块通过公开的 `focus.dart`、`habits.dart`、`review.dart` 使用模型、Provider 与入口。

已接入固定 Handoff 的七个 Screen。第一层包含三主题 UI 与弹层；第二层已接入计时、结算、习惯管理、打卡、统计、偏好、业务持久化与恢复。数字翻页等业务动效属于第三层。

`local_data/` 通过公开模型 API 组合专注和习惯，单一 Riverpod Notifier 拥有业务事实，经 AppPrefs 保存版本化快照。各页面 Provider 只派生展示和发出业务命令，不维护另一份历史。`focus_models.dart`、`habit_models.dart` 为跨模块纯模型入口。

通用时长弹层位于 `common/overlay/`；日期函数位于 `common/time.dart`，可注入时钟及前台校准位于 `common/clock.dart`，根导航与重置协调位于 `app/`。
