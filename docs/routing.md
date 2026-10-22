# 路由

工程使用 Navigator 1.0 命名路由。根 Tab 与页面栈分开管理，编辑和选择面板通过共享弹层打开。

## 注册位置

- 路由常量定义在 `lib/router/routes.dart`。
- 页面注册在 `lib/router/router.dart` 的 `appRoutes`。
- 页面跳转优先使用 `Navigator.of(context).pushNamed(...)`。
- 返回行为使用 `maybePop` 或页面已有的 `CommonAppBar` 返回动作。

## 当前路由

| 路径 | 页面 | 参数与行为 |
| --- | --- | --- |
| `/` | `BootstrapPage` | 默认入口；首帧展示品牌页后替换到 `/home`，减少动态效果时直接展示根页面 |
| `/home` | `YikeHomePage` | 专注、打卡、回顾三个根 Tab；没有额外路由参数 |
| `/settings` | `YikeSettingsPage` | 从专注打开，返回原根页面 |
| `/habit` | `HabitDetailPage` | `RouteSettings.arguments` 为习惯 ID（`String`）；缺失或已删除时展示不存在状态 |

`AppStartup` 在进入默认路由前初始化 AppPrefs，失败时提供重试；页面切换和返回前台不会重新初始化。启动准备与 Bootstrap 的具体视觉偏差见 [已知缺口](known-gaps.md#动效过程与视觉尚未验收)。

## 根导航与面板

`app/navigation.dart` 的 `rootTabProvider` 是根 Tab 的选择来源，`home` 通过 `CommonTabView` 组合三个页面；底部导航切换 Tab，根页面不支持左右滑动切换。专注页内部三个计时模式使用另一组可滑动 Tab，由专注模块处理模式切换确认。

新建/编辑习惯、日期明细、归档列表、时长选择与常用倒计时步骤使用 `AppPop`，不增加命名路由。FlowSheet 的步骤返回与整个面板关闭分别由弹层管理，不能把返回等同于保存。

新增栈级页面时同步补路由常量、注册、参数解析和 Widget test；页面内模式或面板不为凑齐 Screen 数量创建额外路由。
