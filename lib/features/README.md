# Features

按业务模块组织：`focus/`、`habits/`、`review/`、`settings/`、`home/`、`launch/`。模块内页面放 `pages/`，模型放 `models/`，页面 Provider 放 `providers/`，私有图形放 `widgets/`；跨模块通过公开的 `focus.dart`、`habits.dart`、`review.dart` 使用模型、Provider 与入口。

已接入固定 Handoff 的七个 Screen。当前为第一层 UI 与内存展示状态；计时、结算、业务持久化与恢复属于第二层，业务动效属于第三层。通用时长弹层位于 `common/overlay/`；日期格式化和展示时钟位于 `common/time.dart`，根导航协调状态位于 `app/navigation.dart`。
