import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Flutter Target 自有的静态玻璃选中面。
///
/// 它只复刻 [TabBar.indicator] 需要的表面、圆角和阴影；位置、尺寸与动画
/// 完全由 Flutter 的 TabBar indicator painter 管理。
@immutable
class LiquidGlassDecoration extends Decoration {
  const LiquidGlassDecoration({
    required this.surfaceColor,
    required this.opacity,
    required this.borderRadius,
    required this.shadow,
  }) : assert(opacity >= 0 && opacity <= 1);

  final Color surfaceColor;
  final double opacity;
  final BorderRadius borderRadius;
  final BoxShadow shadow;

  Color _applyOpacity(Color color) =>
      color.withValues(alpha: (color.a * opacity).clamp(0.0, 1.0));

  @override
  bool get isComplex => shadow.blurRadius > 0;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _LiquidGlassBoxPainter(this);

  @override
  Decoration? lerpFrom(Decoration? a, double t) {
    if (a is LiquidGlassDecoration) {
      return LiquidGlassDecoration.lerp(a, this, t);
    }
    return super.lerpFrom(a, t);
  }

  @override
  Decoration? lerpTo(Decoration? b, double t) {
    if (b is LiquidGlassDecoration) {
      return LiquidGlassDecoration.lerp(this, b, t);
    }
    return super.lerpTo(b, t);
  }

  static LiquidGlassDecoration lerp(
    LiquidGlassDecoration a,
    LiquidGlassDecoration b,
    double t,
  ) => LiquidGlassDecoration(
    surfaceColor: Color.lerp(a.surfaceColor, b.surfaceColor, t)!,
    opacity: ui.lerpDouble(a.opacity, b.opacity, t)!,
    borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t)!,
    shadow: BoxShadow.lerp(a.shadow, b.shadow, t)!,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiquidGlassDecoration &&
          surfaceColor == other.surfaceColor &&
          opacity == other.opacity &&
          borderRadius == other.borderRadius &&
          shadow == other.shadow;

  @override
  int get hashCode => Object.hash(surfaceColor, opacity, borderRadius, shadow);
}

class _LiquidGlassBoxPainter extends BoxPainter {
  const _LiquidGlassBoxPainter(this.decoration);

  final LiquidGlassDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;

    final rect = offset & size;
    final rrect = decoration.borderRadius.toRRect(rect);
    final shadow = decoration.shadow.copyWith(
      color: decoration._applyOpacity(decoration.shadow.color),
    );
    final shadowRRect = rrect.inflate(shadow.spreadRadius).shift(shadow.offset);

    if (shadow.color.a > 0 && shadow.blurRadius > 0) {
      canvas.drawRRect(shadowRRect, shadow.toPaint());
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..isAntiAlias = true
        ..color = decoration._applyOpacity(decoration.surfaceColor),
    );
  }
}
