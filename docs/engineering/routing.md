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

`AppStartup` 在进入默认路由前初始化 AppPrefs，失败时提供重试；页面切换和返回前台不会重新初始化。Bootstrap 负责品牌展示和进入根页面，准备完成后立即导航。

## 根导航与面板

`app/navigation.dart` 的 `rootTabProvider` 是根 Tab 的选择来源，`home` 通过 `CommonTabView` 组合三个页面；底部导航切换 Tab，根页面不支持左右滑动切换。专注页内部模式 Tab 不支持滑动。

番茄钟、正计时和倒计时分别保存会话状态，切换只更新所选模式。站内状态条提供模式定位，模态期间隐藏并禁止交互，最后一层退场后恢复。通知定位通过启动目标队列等待存储和导航就绪，保护未提交草稿，并处理失效目标；交互规则见 [通知提醒](../product/logic-and-interactions.md#通知提醒)。

正计时右侧记圈、新建/编辑习惯、日期明细、归档列表、时长选择与常用倒计时底部面板使用 `AppPop`，不增加命名路由。FlowSheet 的步骤返回与整个面板关闭分别由弹层管理，不能把返回等同于保存。倒计时编辑复用完整设置页与原面板，关闭面板留在设置页，不创建空壳专用页面。

新增栈级页面时同步补路由常量、注册、参数解析和 Widget test；页面内模式或面板不为凑齐 Screen 数量创建额外路由。

## 返回、焦点与可见性

栈页面返回保留来源根 Tab、模式和滚动。表单草稿按各自规则提交；设置滚轮稳定后自动保存，关闭不回滚已保存值。表盘草稿在手势收束或离开 / 后台中断时提交，轻触不改值。其它明确保存的表单取消、系统返回和遮罩关闭不提交。脏草稿与短记录分别按对应确认规则处理，异步回调先检查 mounted 和请求身份。关闭编辑与选择面板时释放输入焦点，键盘不覆盖固定操作区。

装饰动画同时遵守前台、路由与当前 Tab 可见性；覆盖路由不停止业务时钟。保活不等于可见，恢复直接显示当前状态，不补播完成或打卡。应用使用 Navigator 1.0，各平台默认采用 iOS 栈转场；路由框架调整须有明确导航需求，普通动效使用共享转场。

## 原生外部目标

通知与桌面组件通过 `app/external_targets.dart` 共用单一查看目标队列。等待存储读取成功、Bootstrap 结束和全部模态真实退场后，回到既有根页，选择专注模式或打卡根页并定位有效习惯；不新压一份根页、不丢未提交草稿。已删除 / 归档的习惯只进入打卡页并提示。

`yike://surface?v=1&target=focus|habits` 为版本化组件入口，iOS SceneDelegate 与 Android MainActivity 缓冲冷 / 热启动 URL，关闭 Flutter 自动深链以免与根导航重复处理。查看入口不执行动作；pause / resume 另需完整身份参数，经共享协调器校准验证再调用唯一写入者，失效仅打开对应页面。命令处理与安全导航等待独立，详见 [原生组件与实时活动](system-surfaces.md)。
