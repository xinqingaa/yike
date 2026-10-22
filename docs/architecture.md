# 工程架构

## 目录边界

```text
lib/
├── app/              MaterialApp 和应用启动
├── router/           命名路由常量和注册表
├── theme/            颜色、文字、尺寸和 ThemeExtension
├── storage/          AppPrefs：MMKV 偏好与业务快照
├── common/
│   ├── widgets/      可复用 UI 组件
│   └── overlay/      AppPop 共享弹层入口
└── features/         按业务 feature 组织的页面、模型与页面 Notifier
```

依赖方向为：

```text
features -> common / theme / router / storage
app      -> router / theme / common / overlay / storage
theme    -> storage（仅主题偏好）
```

`router` 只在注册表导入页面；`common`、`theme` 和 `storage` 不依赖具体业务 feature。页面不得通过反向 import 依赖另一个 feature 的私有实现。feature 不得直接依赖 `mmkv`。

## 状态管理

工程只使用已安装的 `flutter_riverpod`。所有驱动界面变化的状态通过 Riverpod 管理。页面业务状态放进该页 feature 的 `Notifier` 或 `AsyncNotifier`，不保存在 Widget 的可变字段中。Target adapter 不推断状态库；本文件是状态管理的权威来源。

- 应用级状态：theme、AppPrefs 读写，放在 `theme/` 或 `storage/`。
- 页面业务状态：筛选、查询、Case/variant、表单值、校验、加载/空/错误壳，放在同 feature 的 `Notifier` 或 `AsyncNotifier`。
- Flutter 控制器：`TextEditingController`、`TabController`、`ScrollController` 由 Widget 生命周期持有和释放；需要 ref 时使用 ConsumerStatefulWidget。纯控制器或派生几何缓存不另建响应式数据源，业务字段变更经 Notifier 同步。
- 组件内部交互：按压、密码显隐、清除按钮显隐同样使用 Riverpod。简单值可用 `common/state/local_value.dart` 的类型化 Notifier，Provider 身份由所属 ConsumerState 持有，自动释放；不能把所有实例放进一个全局状态表。
- 异步初始化：启动准备使用 FutureProvider，重试通过 invalidate 重新执行；加载/错误/成功状态由 AsyncValue 决定。
- 控制器桥接：SearchBar 的 ControllerText Notifier 监听实际 TextEditingController，Provider 负责撤销监听，Widget 负责其自建控制器的释放。受控组件的业务值仍由调用方 Provider 管理。

产品页、公共组件及 Demo 的响应式状态统一使用 Riverpod；工程代码禁止 `setState`、`StatefulBuilder`，也不引入 ValueNotifier/ChangeNotifier 作为平行状态管理。ConsumerStatefulWidget 仅承载 Provider 身份、Flutter 控制器和订阅等生命周期对象，显示值由 ref.watch 读取。嵌套 ProviderScope 中的偏好和主题依赖必须显式声明 dependencies，保证覆盖在正确作用域生效。

跨页共享只有在至少两个 feature 使用且职责稳定时才提升到 `common` 之外的共享 Provider。不要在单个页面中引入第二套状态库。

## 本地存储

只通过 `AppPrefs` 访问 MMKV。生产实现为 `MmkvAppPrefs`，由 `AppStartup` 等待初始化成功后 override `appPrefsProvider`。测试使用 `test/support/fake_app_prefs.dart`，不加载原生存储。当前偏好 key：

- `theme_mode`：`light` | `dark` | `system`（一刻默认跟随系统）
- `theme_pack`：已注册的类型化主题包 ID
- `yike_snapshot_v1`：版本化业务快照，包含初始化日期、计时偏好、会话、周期、专注记录、习惯与打卡身份。由 `features/local_data` 负责组合序列化和原子保存；feature 只通过 AppPrefs，禁止直接 MMKV。

计时与习惯各自保留模型与规则；跨模块快照协调放在 local_data 模块。公开的 focus_models.dart / habit_models.dart 只导出模型和纯逻辑，避免反向导入页面。单一 LocalData Notifier 拥有业务事实，页面 Provider 只派生投影；tick 不写存储，阶段边界和用户操作才保存。

`app/local_data_boundary.dart` 处理读取阻断和保存失败重试；`storage/preference_writer.dart` 保留失败的外观写入。重置由 `app/reset_data.dart` 协调业务快照、外观、根导航、回顾选择和撤销提示，feature 不相互导入私有页面。业务快照为单 key 写入，外观两项独立保存；重置任一写入失败均显示未保存状态，重试当前结果。

不要为未提交表单、Evidence 固定文案或截图 Case 创建存储。需要新 key 时先改本文白名单，再改 `AppPrefs`。

## 页面落点

- 一个页面及其私有模型和页面 Notifier 放在同一个 feature 目录。
- 共用状态、组件或弹层只有在至少两个 feature 使用且职责稳定时才进入 `common/`。
- 业务页面不得直接持有 `RefreshController`、`PopupHandle` 等共享基础设施的生命周期，优先使用对应 Common 组件或 `AppPop`。

## 新增页面

1. 在 `lib/features/<feature>/` 添加页面、必要模型和同目录 Notifier。
2. 在 `lib/router/routes.dart` 添加路由常量。
3. 在 `lib/router/router.dart` 注册 `WidgetBuilder`。
4. 有参数时通过 `RouteSettings.arguments` 传入，并在目标页面集中解析。
5. 在产品导航流程中接入页面；生成工程以 Bootstrap 为入口。
6. 新的持久化 key 先改本文白名单，再改 `AppPrefs`。
7. 遵循 [components.md](components.md) 和 [theme.md](theme.md)。

## 禁止事项

- 不在任何应用代码中以 `setState`、`StatefulBuilder` 或第二套状态机制更新界面；公共组件、Demo 和启动页没有例外。
- 不在 feature 内复制 `Common*` 组件。
- 不直接写新的颜色、字号、圆角或间距数字来绕过 `TS`。
- 不把临时展示数据误写成网络请求或持久化逻辑。
- 不在 feature 中直接使用 `MMKV`。
- 不为未被 Evidence 或产品需求证明的状态创建额外入口。

## 一刻模块划分

`focus` 拥有计时展示、计时偏好与专注记录模型；`habits` 拥有习惯模型与打卡状态；`review` 通过前两者的公开模块 API 消费记录，持有自己的周期选择；`settings` 通过公开模块 API 修改配置。`home` 组合三个入口，`launch` 负责启动展示。根 Tab 协调由 `app/navigation.dart` 提供，共用日期函数与 todayProvider 在 `common/time.dart`。
