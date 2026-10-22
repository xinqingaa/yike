# 静态资源

Flutter 静态资源统一放在 `asset/`，按职责归属分目录。`base/` 用于跨原型的公共资源，其它一级目录使用原型 ID；不能根据文件名推断归属，也不再建立 `assets/icons/`、`assets/themes/` 或原稿参考目录。

```text
asset/
  base/icons/        公共图标
  yike/icons/        yike 专属图标
  yike/artwork/      yike 主题图形与状态图层
```

同一目录内按资源用途扩展 `images/` 等子目录，不按页面另存公共资源，不在多个归属下复制同一文件。新增文件须同时登记 `pubspec.yaml`；禁止把整个原型目录复制进应用资源包。

PBWork 是 DS SVG 的唯一维护端。同步过程读取其原始 SVG，转换成 PNG 后写入所属目录，Flutter 不保留 SVG。同步图标和图形通过导出器维护，不手工补 PNG、枚举或另一套参考原稿；具体操作见 [DS Target Sync Skill](../.agents/skills/proto-bridge-ds-target-sync/SKILL.md)。

`proto-bridge.icons.json` 的 owner 决定图标归属：`shared` 对应 `base`，原型 ID 对应同名目录；文件路径和 Dart 资源映射同时生成。主题资源由实际拥有该资源的主题包归属决定，公共基础包对应 base，原型主题包对应其原型 ID。消费者使用生成路径，不从枚举名或文件名前缀拼接路径。

`icons/` 与 `artwork/` 中的同步文件通过对应导出器维护。导出器只清理上一份清单管理、且本次不再使用的文件，保留其它产品文件。指定原型时只生成公共资源、该原型图标及其绑定主题包和继承依赖。未指定原型时导出全部已登记范围。

PNG 的像素尺寸与界面逻辑尺寸分开：组件通过主题指定显示宽高，高倍率不会扩大点击区域或图形尺寸。主题状态图层按登记共用，禁止为同一图层复制普通版与专注版文件。

## 资源选择与颜色

图标从 `proto-bridge.icons.json` 与生成的 `CommonIconName` 选择；主题图形从 `proto-bridge.themes.json.artwork` 选择。使用元数据中的默认图、`sessionAsset`、`layerAsset` 与命名 view，不从 URL、文件名后缀或截图猜路径，不重绘已有同步资源。

原 SVG 自带颜色的 intrinsic 图形保留原色，不传 `Image.color` 覆盖；currentColor 单色图标才按主题 tone 着色。图标导出使用 3 倍 PNG，保留透明度；主题 artwork 按原画布与主题 `size.plot` 计算 3 倍像素尺寸。

机械倒计时的专注过程图与普通机械图不同，暂停和休息层可由 `layerAsset` 共用。水位的 `rest`、`wave`、`glass` 与日影的 `shadow` 是独立命名视图；静态资源同步不包含水位裁切、指针旋转或阴影变化等业务动画。比例与图层组合分别由 `lib/theme/yike_geometry.dart`、`lib/theme/yike_artwork.dart` 和共享表盘实现消费。

## 固定资源核对

页面采集只固定资源身份、源摘要、使用信息和截图，正常路径不再重复归档 DS 原文件；页面可见图像实际加载失败仍使对应 Case 失败。消费页面 Evidence 时，图标信息可在节点 props 的 name/icons 中读取，表盘的 props.artwork 分开保留 declared、sourceDigest 与实际 image views。配合本地生成清单选择已有 PNG，不从 URL 或截图猜资源。

固定版本不匹配时记录同步缺口，不以相似图代替。逐资产实际使用核验与历史原稿恢复的限制见 [已知缺口](known-gaps.md#资源与-review-工具限制)；旧归档 Blob 保持原有固定读取兼容。
