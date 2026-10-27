# Theme 与 Token

主题采用唯一的类型化 `AppThemePack`，通过 `TS extends ThemeExtension<TS>` 放入 Material Theme。组件从当前 BuildContext 读取，局部 Theme 与弹层不会改写全局主题实例。

```dart
final ts = TS.of(context);
Text('标题', style: ts.textStyle.title);
```

## 主题包

`lib/theme/theme_pack.dart` 定义唯一的类型化主题模型；`generated_theme_packs.dart` 是 Core 解析表到 Flutter 的生成结果，不手工维护。身份使用 `packId/themeId`，明暗模式独立；注册表来自 `generatedThemePacks`，没有样例包或旧主题兼容实现。

一刻在设置页选择机械、水位或日影表盘，并独立选择浅色、深色或跟随系统。默认机械、跟随系统；选择作用于页面、组件及弹层，并经 AppPrefs 恢复。`themePackProvider` 与 `themeModeProvider` 是唯一选择状态；组件通过最近的 TS ThemeExtension 读取。

主题包、导入清单与映射身份由生成工具维护；本地设计量通过类型化扩展点提供。机械主题的正文 / 数字字重 400、标题 / 标签字重 500，以及三主题统一的标题 / 标签 / 说明 / 展示字距 `0.02em`，直接维护在对应字体与 tracking value 中，并同步本地主题矩阵，不叠加排版覆盖层。这些本地排版值不涉及外部 DS，显式重新生成主题时须保留。其它生成值遵守同步边界，只有明确的外部 DS 任务才使用 [DS Target Sync Skill](../../.agents/skills/proto-bridge-ds-target-sync/SKILL.md)。主题组件键参与解析；图片资源按明暗模式选择，并由组件指定逻辑尺寸。

`proto-bridge.themes.json` 记录选择范围、主题与模式矩阵、源摘要和解析值。同步门禁同时核对生成的 Dart 内容和这个矩阵，不能只凭 accessor 存在或源端 fingerprint 声明主题已落地。仅显式固定 Handoff 专项需要使用其固定主题表，不读取 active/latest。

## Token 职责

`ts.colors`、`ts.textStyle`、`ts.spacing`、`ts.sizing`、`ts.radius`、`ts.opacity`、`ts.motion`、`ts.elevation`、`ts.border`、`ts.layout`、`ts.layer`、`ts.effect`、`ts.assets` 是组件使用入口。具体设计量只放在主题目录；页面和公共组件不得另建平行常量或复制颜色数值。本地几何与动效节拍分别维护在 `YikeGeometry`、`YikeMotion`；它们不冒充导入 Contract 的 Token。

`protoBridgeTokenSnapshot(ts)` 接收明确的上下文主题，用于调试和映射验证。`proto-bridge.target.json` 维护可绑定主题键的精确 accessor。映射有效仅说明落点可访问；组件的视觉、状态和实际消费仍需单独验证。

`transparent` / `none` 是绑定字面量，不建立 Token accessor。资源未提供时由组件按 Contract 回退。Flutter 用逻辑像素、比例、Curve、BoxShadow 表达 Web 对应语义。相对字距保留为类型化 AppLetterSpacing，在使用处按实际字号解析；不把 em 直接当作像素。CSS 内阴影、滤镜饱和度和连续字重使用明确的平台翻译，不宣称逐像素一致。

## 主题切换

Material Theme 和 TS 使用同一主题包。`TS.lerp` 与 `theme_interpolation.dart` 连续插值颜色、文字、间距、尺寸、圆角、透明度、布局、阴影和效果参数。主题包身份、明暗枚举、motion、layer 与资源引用采用对应端点；表盘通过 `artworkThemes` 按同一进度混合原图层，比例连续插值；快速反向切回已有端点时累加相同图层的贡献，保证总权重为 1。主题选择卡片的边框读取同一组权重，选择语义即时更新，视觉从当前进度衔接。组件不得缓存 BuildContext 对应的主题供其它页面使用。

主题过渡使用 `motion.durationSlow` 与 `motion.easingGentle`；系统减少动态效果时主题动画时长归零。相关检查见 [测试与视觉验证](testing.md)。

## 原稿与分层资源

`proto-bridge.themes.json.artwork` 按所属包登记主题图形：`source` 仅记录 PBWork 来源包、相对 DS glyphs/ 的源文件标识和源摘要；`raster` 与 `layers` 记录 Flutter PNG 路径、viewBox、逻辑尺寸及专注过程变体关联。SVG 原稿只在 PBWork 维护，Flutter 同步只生成 PNG，不复制 SVG。

PNG 按原始画布与主题 size.plot 中较大的宽度、3 倍像素密度计算。相同状态图层通过 `layerAsset` 显式共用，元数据指向唯一 PNG。资源按主题包选择范围同步，业务表盘动画由 Flutter 呈现层实现。

资源来源、目录和精确复用见 [资源规范](assets.md)。显式 DS 专项的同步检查读取源文件及摘要，检查 Flutter 元数据与 PNG 尺寸；普通客户端检查只验证本地基线，不访问外部源码。

## 视口与文字适配

应用的准备、失败重试与正式页面共用 `AppViewport`，以手机设计基准 390×844 初始化 flutter_screenutil。`AppMetrics` 在初始化后捕获不可变的转换因子，窗口尺寸变化时重建 Theme。类型化主题包保留 Producer 原始数值；TS 在消费层转换一次，组件直接使用 TS，不再追加 `.w`、`.h`、`.r` 或 `.sp`。

横向边界与宽度使用 `.w`，纵向控件和面板高度使用 `.h`；圆角、等比图形、通用间距、边框与阴影使用 `.r`；字号使用 `.sp`。长宽和等比缩放因子有上下限，字号的视口因子不超过 1，避免大窗口持续放大文字。具体边界与文字角色上限唯一维护在 `lib/theme/app_metrics.dart`。字体行高倍数、字重、比例、行数、动画时间及真实屏幕/锚点坐标不缩放；相对字距按转换后的字号解析。

Flutter 的正文、标签与标题使用 Target 的紧凑文字档位上限，原型数字展示保留独立角色。系统 TextScaler 仍由 Flutter 生效，不通过屏蔽系统字号解决偏大。ThemeData 的默认文本样式与显式组件样式使用同一套 TS。无视口转换的 TS 用于校验原始设计值，不作为应用入口主题。

菜单定位、边缘翻转、锚点跟随和滚动由 unified_popups 处理；AppPop 按库示例传入菜单与主题样式，保留其默认有限宽度，仅设置主题最大高度，不另建屏幕几何算法；点击区域与图片大小独立，输入框前后缀中的 CommonIcon 在槽位内按主题尺寸居中。平台原生工具栏等框架规格保留原生尺寸，菜单边界和点击目标不因比例适配丢失约束。静态资源目录遵循 [资源规范](assets.md)。

## Flutter 自有扩展

新增本地能力先复用现有 TS 设计量；新的跨组件颜色/尺寸按语义增加类型化本地主题属性，并在浅深模式和插值中验证。几何比例、幅度和节拍可进入本地 YikeGeometry/YikeMotion。除本页规定的机械字重及三主题统一字距维护项外，生成文件与 proto-bridge 清单只在显式同步中更新；普通组件使用本地扩展点。

类型环与图例使用本地 `AppChartColors`，通过 `ts.chartTypeColors` 读取三种类型颜色；三主题共用，按浅深模式提供颜色。该配色是 Flutter 产品扩展，不改写生成主题包。
