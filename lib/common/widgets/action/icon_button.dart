import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import 'button.dart';
import 'icon.dart';
import '../display/glass_surface.dart';

/// 对齐 pbwork Icon Button `tone`。
enum CommonIconButtonTone { primary, secondary }

/// 对齐 pbwork Icon Button `variant`。
enum CommonIconButtonVariant { tonal, flat, outlined, text }

/// 紧凑图片操作；[label] 同时作为 tooltip 与无障碍名称。
///
/// [quarterTurns] 是 Target 便利参数，用于旋转图标（例如返回箭头），不是 Producer prop。
class CommonIconButton extends StatelessWidget {
  const CommonIconButton({
    super.key,
    this.name,
    this.icon,
    required this.label,
    this.onPressed,
    this.size = CommonControlSize.md,
    this.tone = CommonIconButtonTone.secondary,
    this.variant = CommonIconButtonVariant.tonal,
    this.loading = false,
    this.disabled = false,
    this.quarterTurns = 0,
    this.material = CommonSurfaceMaterial.solid,
  }) : assert((name == null) != (icon == null));

  final CommonIconName? name;

  /// Flutter-owned symbols absent from the curated bitmap set.
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final CommonControlSize size;
  final CommonIconButtonTone tone;
  final CommonIconButtonVariant variant;
  final bool loading;
  final bool disabled;
  final int quarterTurns;
  final CommonSurfaceMaterial material;

  bool get _enabled => !disabled && !loading && onPressed != null;

  double _iconSize(TS ts) => switch (size) {
    CommonControlSize.sm => ts.sizing.iconSm,
    CommonControlSize.md => ts.sizing.iconMd,
    CommonControlSize.lg => ts.sizing.iconLg,
  };

  double _buttonSize(TS ts) => switch (size) {
    CommonControlSize.sm || CommonControlSize.md => ts.sizing.touch,
    CommonControlSize.lg => ts.sizing.controlLg,
  };

  Color _color(TS ts) => switch (tone) {
    CommonIconButtonTone.primary => ts.colors.primary,
    CommonIconButtonTone.secondary => ts.colors.secondary,
  };

  Color? _background(TS ts) => switch (variant) {
    CommonIconButtonVariant.flat => _color(ts),
    CommonIconButtonVariant.tonal => switch (tone) {
      CommonIconButtonTone.primary => ts.colors.primarySoft,
      CommonIconButtonTone.secondary => ts.colors.secondarySoft,
    },
    CommonIconButtonVariant.outlined || CommonIconButtonVariant.text => null,
  };

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final foreground = variant == CommonIconButtonVariant.flat
        ? switch (tone) {
            CommonIconButtonTone.primary => ts.colors.onPrimary,
            CommonIconButtonTone.secondary => ts.colors.onSecondary,
          }
        : _color(ts);

    Widget result = IconButton(
      onPressed: _enabled ? onPressed : null,
      tooltip: label,
      iconSize: _iconSize(ts),
      style: IconButton.styleFrom(
        fixedSize: Size.square(_buttonSize(ts)),
        shape: const CircleBorder(),
        foregroundColor: foreground,
        backgroundColor: material == CommonSurfaceMaterial.glass
            ? Colors.transparent
            : _background(ts),
        side: variant == CommonIconButtonVariant.outlined
            ? BorderSide(color: _color(ts), width: ts.border.widthHairline)
            : null,
      ),
      icon: loading
          ? SizedBox(
              width: _iconSize(ts),
              height: _iconSize(ts),
              child: CircularProgressIndicator(
                strokeWidth: ts.sizing.progressStroke,
                color: foreground,
              ),
            )
          : RotatedBox(
              quarterTurns: quarterTurns,
              child: icon != null
                  ? Icon(icon, size: _iconSize(ts), color: foreground)
                  : CommonIcon(
                      name: name!,
                      dimension: _iconSize(ts),
                      color: foreground,
                    ),
            ),
    );
    if (material == CommonSurfaceMaterial.glass) {
      result = Align(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension: _buttonSize(ts),
          child: CommonGlassSurface(
            borderRadius: BorderRadius.circular(ts.radius.full),
            tint: tone == CommonIconButtonTone.primary
                ? ts.colors.iconButtonGlassPrimaryTint
                : null,
            child: result,
          ),
        ),
      );
    }
    return Opacity(
      opacity: disabled ? ts.opacity.disabled : ts.opacity.visible,
      child: result,
    );
  }
}
