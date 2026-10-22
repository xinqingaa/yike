import 'package:flutter/material.dart';
import 'package:unified_popups/liquid_glass.dart';

import '../../../theme/ts.dart';

enum CommonSurfaceMaterial { solid, glass }

enum CommonGlassEdges { all, bottom }

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
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final bool clear;
  final bool reduceTransparency;
  final Color? tint;
  final CommonGlassEdges edges;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final radius = borderRadius ?? BorderRadius.zero;
    if (reduceTransparency || MediaQuery.highContrastOf(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: ts.colors.surface,
          border: edges == CommonGlassEdges.bottom
              ? Border(bottom: ts.border.defaultBorder)
              : Border.fromBorderSide(ts.border.defaultBorder),
          borderRadius: radius,
        ),
        child: ClipRRect(borderRadius: radius, child: child),
      );
    }
    return LiquidGlass(
      borderRadius: radius,
      edgePainterBuilder: (radius, style) =>
          _RoundedGlassEdge(borderRadius: radius, style: style, edges: edges),
      style: ts.glassStyle(clear: clear, tint: tint),
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
