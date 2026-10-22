import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

class CommonRingProgress extends StatelessWidget {
  const CommonRingProgress({
    super.key,
    required this.value,
    this.max = 100,
    this.label,
  });
  final double value;
  final double max;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final ratio = max.isFinite && max > 0 && value.isFinite
        ? (value / max).clamp(0.0, 1.0)
        : 0.0;
    final percentage = '${(ratio * 100).round()}%';
    return Semantics(
      label: label,
      value: percentage,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: ts.sizing.ring,
          child: CustomPaint(
            painter: _RingPainter(
              ratio,
              ts.colors.primary,
              ts.colors.primarySoft,
              ts.sizing.progressStroke,
            ),
            child: Center(
              child: Text(percentage, style: ts.textStyle.numericTitle),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.ratio, this.fill, this.track, this.stroke);
  final double ratio;
  final Color fill;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    if (rect.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = track,
    );
    if (ratio > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        ratio * math.pi * 2,
        false,
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      ratio != oldDelegate.ratio ||
      fill != oldDelegate.fill ||
      track != oldDelegate.track ||
      stroke != oldDelegate.stroke;
}
