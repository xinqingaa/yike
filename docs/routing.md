# 路由

工程使用 Navigator 1.0 命名路由。

## 注册位置

- 路由常量定义在 `lib/router/routes.dart`。
- 页面注册在 `lib/router/router.dart` 的 `appRoutes`。
- 页面跳转优先使用 `Navigator.of(context).pushNamed(...)`。
- 返回行为使用 `maybePop` 或页面已有的 `CommonAppBar` 返回动作。

## 当前路由

- `/` Bootstrap 空壳，等待固定 PBWork Handoff。

业务页面按 Screen 新增时同步补路由常量、注册、参数解析和 Widget test。
