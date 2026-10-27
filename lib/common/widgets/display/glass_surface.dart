import 'package:flutter/material.dart';
import 'package:unified_popups/liquid_glass.dart';

import '../../../theme/ts.dart';
import '../../accessibility/reduce_transparency.dart';

enum CommonSurfaceMaterial { solid, glass }

enum CommonGlassEdges { all, bottom, none }

/// A material-only container; scrolling, input and navigation belong to its child.
class CommonGlassSurface extends StatelessWidget {
  const CommonGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.clear = false,
    this.reduceTransparency = false,
    this.tint,
    this.edges = CommonGlassEdges.all,
    this.reveal = 1,
    this.backdropBlendMode = BlendMode.srcOver,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final bool clear;
  final bool reduceTransparency;
  final Color? tint;
  final CommonGlassEdges edges;

  /// Scroll-driven blend from a solid surface to glass, without fading content.
  final double reveal;
  final BlendMode backdropBlendMode;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ReduceTransparency.enabled,
    builder: (context, reduced, _) => _buildSurface(context, reduced),
  );

  Widget _buildSurface(BuildContext context, bool systemReduced) {
    final ts = TS.of(context);
    final radius = borderRadius ?? BorderRadius.zero;
    if (reduceTransparency ||
        systemReduced ||
        MediaQuery.highContrastOf(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: ts.colors.surface,
          border: edges == CommonGlassEdges.none
              ? null
              : edges == CommonGlassEdges.bottom
              ? Border(bottom: ts.border.defaultBorder)
              : Border.fromBorderSide(ts.border.defaultBorder),
          borderRadius: radius,
        ),
        child: ClipRRect(borderRadius: radius, child: child),
      );
    }
    final glass = ts.glassStyle(clear: clear, tint: tint);
    return LiquidGlass(
      borderRadius: radius,
      backdropBlendMode: backdropBlendMode,
      edgePainterBuilder: (radius, style) =>
          _RoundedGlassEdge(borderRadius: radius, style: style, edges: edges),
      style: glass.copyWith(
        backgroundColor: Color.lerp(
          ts.colors.surface,
          glass.backgroundColor,
          reveal,
        ),
        blurSigma: glass.blurSigma * reveal,
        borderColor: glass.borderColor!.withValues(
          alpha: glass.borderColor!.a * reveal,
        ),
        topHighlightColor: glass.topHighlightColor!.withValues(
          alpha: glass.topHighlightColor!.a * reveal,
        ),
        shadowColor: glass.shadowColor!.withValues(
          alpha: glass.shadowColor!.a * reveal,
        ),
      ),
      enableShadow: edges == CommonGlassEdges.all,
      child: child,
    );
  }
}

class _RoundedGlassEdge extends LiquidGlassEdgePainter {
  const _RoundedGlassEdge({
    required super.borderRadius,
    required super.style,
    required this.edges,
  });

  final CommonGlassEdges edges;

  @override
  bool shouldRepaint(covariant LiquidGlassEdgePainter oldDelegate) =>
      oldDelegate is! _RoundedGlassEdge ||
      edges != oldDelegate.edges ||
      super.shouldRepaint(oldDelegate);
  @override
  void paint(Canvas canvas, Size size) {
    if (edges == CommonGlassEdges.none) return;
    if (edges == CommonGlassEdges.bottom) {
      final width = style.source.outlineWidth;
      if (size.isEmpty || width <= 0) return;
      canvas.drawLine(
        Offset(0, size.height - width / 2),
        Offset(size.width, size.height - width / 2),
        Paint()
          ..color = style.borderColor
          ..strokeWidth = width,
      );
      return;
    }
    final inset =
        (style.source.topStrokeWidth > style.source.outlineWidth
            ? style.source.topStrokeWidth
            : style.source.outlineWidth) /
        2;
    final rect = (Offset.zero & size).deflate(inset);
    if (rect.isEmpty) return;
    final shape = borderRadius.toRRect(rect).scaleRadii();
    LiquidGlassEdgePainter(
      borderRadius: BorderRadius.only(
        topLeft: shape.tlRadius,
        topRight: shape.trRadius,
        bottomLeft: shape.blRadius,
        bottomRight: shape.brRadius,
      ),
      style: style,
    ).paint(canvas, size);
  }
}
