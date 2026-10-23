# 工程架构

一刻采用按 feature 组织的 Flutter 客户端架构，Riverpod 管理业务与页面状态，AppPrefs 隔离本地存储。架构围绕现有专注、习惯和回顾演进；新增抽象应解决实际职责、复用或测试问题。

## 目录与依赖

```text
lib/
  app/          应用组合、启动、根导航与跨模块协调
  router/       路由身份、注册与页面栈
  theme/        类型化设计量、主题组合、资源映射与插值
  storage/      AppPrefs、Codec 基类与 MMKV 平台适配
  common/       通用能力、组件、弹层与局部呈现机制
  features/     业务模型、规则、命令、页面与私有组件
```

`app` 是组合入口，可依赖 feature 公开 API 和基础能力。feature 依赖 common、theme、router 与 storage 的公开边界；router 仅在注册表导入页面。common、theme、storage 不反向依赖 feature，theme 只通过 storage 保存外观偏好。feature 不直接使用 MMKV，不导入另一个 feature 的私有页面、Widget 或 Provider 实现。

模块默认包含 `pages/`、`models/`、`providers/`、`widgets/`；复杂纯规则放 `logic/`。简单模块可保持少量文件，不为了目录形式创建空层。公开 barrel 只导出其它模块需要的接口，模型/规则入口与页面入口分开，避免模型消费方间接依赖页面。

## 分层职责

| 层 | 拥有什么 | 边界 |
| --- | --- | --- |
| 页面与 Widget | 布局、语义、焦点、输入控制器、动画与简单导航 | 发出业务意图，不直接序列化、写存储或结算记录 |
| 展示 Provider | 页面选择、草稿、校验、派生展示、动作协调 | 复用同一事实源，缩小订阅范围，清晰表达失败 |
| 模型与纯规则 | 会话状态机、校验、身份关系、统计口径 | 不依赖 Widget、BuildContext、存储或动画完成回调 |
| 数据协调与适配 | 初始化、快照组合、读取、写入、恢复与重试 | 不决定按钮外观、动画或页面构图 |

业务命令先校验身份与状态，再应用纯规则，提交同一份业务事实并尝试保存。消费方通过派生查询读取结果。内存生效与保存成功分开表达，保存重试不重复执行命令。

例如“暂停”：页面发出 pause → FocusActions 读取时间 → FocusEngine 冻结有效用时 → LocalDataController 提交快照 → 展示投影更新读数和操作 → 保存失败由应用边界显示未保存及重试。动画只呈现结果，不在动画结束后才暂停或落盘。

## 一刻模块划分

| 模块 | 当前职责 | 公开入口 |
| --- | --- | --- |
| focus | 会话模型、计时规则、偏好、专注历史与页面 | `focus.dart`、`focus_models.dart` |
| habits | 习惯模型、打卡、详情、编辑与管理 | `habits.dart`、`habit_models.dart` |
| local_data | 组合快照、初始化、提交、读取保护与重试 | `local_data.dart` |
| review | 消费专注和习惯事实，维护周期浏览 | `review.dart` |
| settings | 经公开 API 修改配置 | 设置命名路由 |
| home | 组合三个根页面 | 根命名路由 |
| launch | 品牌展示 | 应用启动流程 |

`LocalDataController` 目前拥有组合业务快照；计时规则留在 FocusEngine，习惯规则留在 habits，统计由记录派生。它不继续吸收 UI、动效或所有 feature 的业务规则。只有出现独立数据源、明显性能问题或职责冲突时，再评估拆分 Repository/协调器。

## 状态管理

业务事实、页面选择与草稿使用 Riverpod；Provider、控制器、一次性反馈和重建规则统一见 [状态管理](state-management.md)。动画由生命周期内的 Flutter Controller/Ticker 驱动，逐帧进度不提升为业务 Provider。

跨页事实只维护一份。展示缓存不能成为第二套统计；修改名称不更换身份；副作用不由 build、派生 getter 或每帧回调执行。异步操作离开页面后不得使用失效 context 或覆盖新的草稿。

## 组件、设计与适配

先检查公开组件与真实构造函数。已有组件语义适用时扩展其受控 API，业务特有组合留在 feature。跨 feature 复用且职责稳定的 UI 才进入 common；时间、身份和生命周期等基础能力可按明确职责独立放入 common。

设计量从 TS 与本地类型化主题扩展点读取；布局用约束表达，不以固定手机坐标拼整页。系统文字缩放、触控目标、安全区与键盘规则见 [组件](components.md) 和 [主题](theme.md)。导入的生成产物与 Flutter 自有设计的维护边界见 [资源](assets.md)。

## 本地存储

只通过 AppPrefs 访问 MMKV，业务快照由 local_data 组合。键白名单、Codec、错误、版本、恢复与重置规则统一在 [存储](storage.md)。新的 key 先更新该文档，再修改类型化注册。时间和前后台策略见 [运行时](runtime.md)。

## 新增与修改功能

先明确用户动作、事实变化、失败结果及可观察行为，再选择所属 feature 和复用接口。栈级页面更新路由常量、注册与参数解析；面板和页面内模式使用各自导航边界。以相关纯规则、Provider、Widget 或原生测试验证用户行为。

新增依赖前检查 Flutter SDK、现有能力与包的公开 API；说明引入目的、平台支持和生命周期，不用新包复制已有基础设施。依赖变更提交 `pubspec.yaml` 与锁文件，生成目录不提交。构建与检查方式见 [测试](testing.md)。

重要产品取舍或跨模块边界变化写入简短决策记录；小范围实现细节直接在代码与所属规范维护。
