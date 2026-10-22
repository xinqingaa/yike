import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../theme/ts.dart';

class CommonBarItem {
  const CommonBarItem({
    required this.id,
    required this.label,
    required this.value,
  });
  final String id;
  final String label;
  final double value;
}

class CommonMiniBars extends StatelessWidget {
  const CommonMiniBars({
    super.key,
    required this.items,
    this.label = '近七日完成次数',
  });
  final List<CommonBarItem> items;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: ts.textStyle.label),
        SizedBox(height: ts.spacing.sm),
        if (items.isEmpty)
          Text('暂无数据', style: ts.textStyle.caption)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width:
                  items.length * (ts.sizing.controlSm + ts.spacing.sm) +
                  ts.spacing.md * 2,
              height: ts.sizing.plot,
              child: CustomPaint(
                painter: _BarsPainter(
                  items: items,
                  ts: ts,
                  direction: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required List<CommonBarItem> items,
    required this.ts,
    required this.direction,
    required this.textScaler,
  }) : items = List.unmodifiable(items),
       values = List.unmodifiable(
         items.map(
           (item) => item.value.isFinite ? math.max(0.0, item.value) : 0.0,
         ),
       );
  final List<CommonBarItem> items;
  final List<double> values;
  final TS ts;
  final TextDirection direction;
  final TextScaler textScaler;
  late final double _maximum = values.fold(1.0, math.max);

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: ts.textStyle.caption),
    textDirection: direction,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final labelHeight = _text('0').height;
    final top = labelHeight + ts.spacing.sm;
    final plotHeight = math.max(
      0.0,
      size.height - top - labelHeight - ts.spacing.sm,
    );
    final bottom = top + plotHeight;
    for (var index = 0; index < items.length; index++) {
      final left =
          ts.spacing.md + index * (ts.sizing.controlSm + ts.spacing.sm);
      final track = Rect.fromLTWH(left, top, ts.sizing.controlSm, plotHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(track, Radius.circular(ts.radius.xs)),
        paint..color = ts.colors.surfaceVariant,
      );
      final height = plotHeight * values[index] / _maximum;
      if (height > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, bottom - height, ts.sizing.controlSm, height),
            Radius.circular(ts.radius.xs),
          ),
          paint..color = ts.colors.primary,
        );
      }
      final value = _text(
        '${values[index] == values[index].truncateToDouble() ? values[index].toInt() : values[index]}',
      );
      value.paint(
        canvas,
        Offset(left + (ts.sizing.controlSm - value.width) / 2, 0),
      );
      final label = _text(items[index].label);
      label.paint(
        canvas,
        Offset(
          left + (ts.sizing.controlSm - label.width) / 2,
          bottom + ts.spacing.sm,
        ),
      );
    }
    canvas.drawLine(
      Offset(ts.spacing.md, bottom),
      Offset(size.width - ts.spacing.md, bottom),
      paint
        ..color = ts.colors.divider
        ..strokeWidth = ts.border.widthHairline,
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (var index = 0; index < items.length; index++)
          CustomPainterSemantics(
            key: ValueKey(items[index].id),
            rect: Rect.fromLTWH(
              ts.spacing.md + index * (ts.sizing.controlSm + ts.spacing.sm),
              0,
              ts.sizing.controlSm,
              size.height,
            ),
            properties: SemanticsProperties(
              label: '${items[index].label}: ${items[index].value}',
              textDirection: direction,
            ),
          ),
      ];

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      !listEquals(items, oldDelegate.items) ||
      ts != oldDelegate.ts ||
      direction != oldDelegate.direction ||
      textScaler != oldDelegate.textScaler;
  @override
  bool shouldRebuildSemantics(covariant _BarsPainter oldDelegate) =>
      shouldRepaint(oldDelegate);
}
