import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

part 'generated_icon_names.dart';

enum CommonIconSize { sm, md, lg }

enum CommonIconTone {
  inherit,
  onSurface,
  muted,
  primary,
  action,
  error,
  success,
  warning,
}

extension CommonIconNameAsset on CommonIconName {
  String get assetPath => _iconAssetPaths[this]!;

  bool get preservesSourceColor => _intrinsicColorIcons.contains(this);
}

/// PBWork `icon` 的 Flutter 实现；使用策展后的稳定图片资源。
class CommonIcon extends StatelessWidget {
  const CommonIcon({
    super.key,
    required this.name,
    this.size = CommonIconSize.md,
    this.tone = CommonIconTone.inherit,
    this.label,
    this.dimension,
    this.color,
  });

  final CommonIconName name;
  final CommonIconSize size;
  final CommonIconTone tone;
  final String? label;
  final double? dimension;
  final Color? color;

  double _size(TS ts) => switch (size) {
    CommonIconSize.sm => ts.sizing.iconSm,
    CommonIconSize.md => ts.sizing.iconMd,
    CommonIconSize.lg => ts.sizing.iconLg,
  };

  Color? _color(TS ts) => switch (tone) {
    CommonIconTone.inherit => null,
    CommonIconTone.onSurface => ts.colors.onSurface,
    CommonIconTone.muted => ts.colors.onSurfaceMuted,
    CommonIconTone.primary => ts.colors.primary,
    CommonIconTone.action => ts.colors.action,
    CommonIconTone.error => ts.colors.error,
    CommonIconTone.success => ts.colors.success,
    CommonIconTone.warning => ts.colors.warning,
  };

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Image.asset(
        name.assetPath,
        width: dimension ?? _size(ts),
        height: dimension ?? _size(ts),
        color: name.preservesSourceColor
            ? null
            : (color ??
                  _color(ts) ??
                  IconTheme.of(context).color ??
                  ts.colors.onSurface),
        filterQuality: FilterQuality.high,
        colorBlendMode: BlendMode.srcIn,
        excludeFromSemantics: label == null || label!.isEmpty,
        semanticLabel: label,
      ),
    );
  }
}
