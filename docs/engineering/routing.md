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
| `/settings` | `YikeSettingsPage` | 从专注打开，返回原根页面；可选 `SettingsRouteArguments(openCountdownPresets: true)` 首帧后自动展开常用项面板 |
| `/statistics` | `StatisticsPage` | `StatisticsRouteArguments` 传入 anchor/month/mode；缺省参数时锚点取应用时钟的今天，不读系统日历。页面独立保留选择，返回不覆盖回顾 |
| `/habit` | `HabitDetailPage` | `RouteSettings.arguments` 为习惯 ID（`String`）；缺失或已删除时展示不存在状态 |

`AppStartup` 在进入默认路由前初始化 AppPrefs，失败时提供重试；页面切换和返回前台不会重新初始化。启动准备与 Bootstrap 的具体视觉偏差见 [已知缺口](../known-gaps.md)。

## 根导航与面板

`app/navigation.dart` 的 `rootTabProvider` 是根 Tab 的选择来源，`home` 通过 `CommonTabView` 组合三个页面；底部导航切换 Tab，根页面不支持左右滑动切换。专注页内部三个计时模式只接受顶部 Tab 点击，不支持滑动。专注模块先处理当前会话确认，再同步业务模式和 TabController；取消确认不会先进入目标页面再返回。

正计时右侧记圈、新建/编辑习惯、日期明细、归档列表、时长选择与常用倒计时步骤使用 `AppPop`，不增加命名路由。FlowSheet 的步骤返回与整个面板关闭分别由弹层管理，不能把返回等同于保存。倒计时编辑复用完整设置页与原面板，关闭面板留在设置页，不创建空壳专用页面。

新增栈级页面时同步补路由常量、注册、参数解析和 Widget test；页面内模式或面板不为凑齐 Screen 数量创建额外路由。

## 返回、焦点与可见性

栈页面返回保留来源根 Tab、模式和滚动。表单草稿按各自规则提交；设置滚轮稳定后自动保存，关闭不回滚已保存值。表盘草稿在手势收束或离开 / 后台中断时提交，轻触不改值。其它明确保存的表单取消、系统返回和遮罩关闭不提交。已有脏草稿确认与短记录确认保留原语义，异步回调先检查 mounted 和请求身份。关闭编辑与选择面板时释放输入焦点，键盘不覆盖固定操作区。

装饰动画同时遵守前台、路由与当前 Tab 可见性；覆盖路由不停止业务时钟。保活不等于可见，恢复直接显示当前状态，不补播完成或打卡。维持 Navigator 1.0 及当前所有平台默认 iOS 栈转场；新增深链需求再评估路由迁移，普通动效不引入新路由框架。
