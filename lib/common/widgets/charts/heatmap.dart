import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../theme/ts.dart';
import 'calendar_dates.dart';

export 'calendar_dates.dart' show CommonHeatmapDay, CommonHeatmapCell;

typedef CommonHeatmapPlotBuilder =
    Widget Function(
      BuildContext context,
      List<List<CommonHeatmapCell>> weeks,
      double maximum,
    );

class CommonHeatmap extends StatefulWidget {
  const CommonHeatmap({
    super.key,
    required this.days,
    this.value,
    this.onChanged,
    this.label = '每日完成记录',
    this.showLabel = true,
    this.readonly = false,
    this.dayLabels = const {},
    this.plotBuilder,
    this.legend,
  });
  final List<CommonHeatmapDay> days;
  final String? value;
  final ValueChanged<String>? onChanged;
  final String label;
  final bool showLabel;
  final bool readonly;
  final Map<String, String> dayLabels;
  final CommonHeatmapPlotBuilder? plotBuilder;
  final Widget? legend;

  @override
  State<CommonHeatmap> createState() => _CommonHeatmapState();
}

class _CommonHeatmapState extends State<CommonHeatmap> {
  late List<List<CommonHeatmapCell>> _weeks;
  late double _maximum;
  void _prepare() {
    _weeks = heatmapWeeks(widget.days);
    _maximum = widget.days
        .where((day) => day.value.isFinite)
        .fold(1.0, (maximum, day) => math.max(maximum, day.value));
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant CommonHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.days, oldWidget.days)) _prepare();
  }

  void _select(CommonHeatmapCell cell) {
    if (!widget.readonly && cell.value != null) {
      widget.onChanged?.call(cell.date);
    }
  }

  void _move(int delta, {bool edge = false}) {
    final available = _weeks
        .expand((week) => week)
        .where((cell) => cell.value != null)
        .toList();
    if (available.isEmpty || widget.readonly) return;
    var index = available.indexWhere((cell) => cell.date == widget.value);
    if (index < 0) index = 0;
    final next = edge
        ? (delta < 0 ? 0 : available.length - 1)
        : (index + delta).clamp(0, available.length - 1);
    _select(available[next]);
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final cell = ts.sizing.iconMd;
    final gap = ts.spacing.xs;
    final header = ts.sizing.controlSm;
    final height = header + cell * 7 + gap * 6;
    final selected = _weeks
        .expand((week) => week)
        .where((cell) => cell.date == widget.value)
        .firstOrNull;
    return Semantics(
      container: !widget.showLabel,
      explicitChildNodes: true,
      label: widget.showLabel ? null : widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabel) ...[
            Text(widget.label, style: ts.textStyle.label),
            SizedBox(height: ts.spacing.sm),
          ],
          if (_weeks.isEmpty)
            Text('暂无数据', style: ts.textStyle.caption)
          else if (widget.readonly && widget.plotBuilder != null)
            widget.plotBuilder!(context, _weeks, _maximum)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ts.sizing.controlSm,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: header),
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) SizedBox(height: gap),
                        SizedBox(
                          height: cell,
                          child: Center(
                            child: Text(
                              const ['一', '二', '三', '四', '五', '六', '日'][i],
                              style: ts.textStyle.micro,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.arrowLeft,
                        ): () =>
                            _move(-7),
                        const SingleActivator(
                          LogicalKeyboardKey.arrowRight,
                        ): () =>
                            _move(7),
                        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                            _move(-1),
                        const SingleActivator(
                          LogicalKeyboardKey.arrowDown,
                        ): () =>
                            _move(1),
                        const SingleActivator(LogicalKeyboardKey.home): () =>
                            _move(-1, edge: true),
                        const SingleActivator(LogicalKeyboardKey.end): () =>
                            _move(1, edge: true),
                        const SingleActivator(LogicalKeyboardKey.enter): () {
                          if (selected != null) _select(selected);
                        },
                        const SingleActivator(LogicalKeyboardKey.space): () {
                          if (selected != null) _select(selected);
                        },
                      },
                      child: Focus(
                        canRequestFocus:
                            !widget.readonly && widget.onChanged != null,
                        child: GestureDetector(
                          onTapUp: widget.readonly
                              ? null
                              : (details) {
                                  final point = details.localPosition;
                                  if (point.dy < header) return;
                                  final column = (point.dx / (cell + gap))
                                      .floor();
                                  final row =
                                      ((point.dy - header) / (cell + gap))
                                          .floor();
                                  if (column >= _weeks.length ||
                                      row >= 7 ||
                                      row < 0 ||
                                      point.dx % (cell + gap) > cell ||
                                      (point.dy - header) % (cell + gap) >
                                          cell) {
                                    return;
                                  }
                                  _select(_weeks[column][row]);
                                },
                          child: SizedBox(
                            width: _weeks.length * (cell + gap) - gap,
                            height: height,
                            child: CustomPaint(
                              painter: _HeatmapPainter(
                                weeks: _weeks,
                                maximum: _maximum,
                                selected: widget.readonly ? null : widget.value,
                                labels: widget.dayLabels,
                                ts: ts,
                                direction: Directionality.of(context),
                                onSelect:
                                    widget.readonly || widget.onChanged == null
                                    ? null
                                    : _select,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: ts.spacing.sm),
          widget.legend ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('少', style: ts.textStyle.caption),
                  SizedBox(width: ts.spacing.xs),
                  for (final color in [
                    ts.colors.surfaceVariant,
                    ts.colors.primarySoft,
                    ts.colors.primary,
                  ])
                    Padding(
                      padding: EdgeInsets.only(right: ts.spacing.xs),
                      child: SizedBox.square(
                        dimension: ts.sizing.iconSm,
                        child: ColoredBox(color: color),
                      ),
                    ),
                  Text('多', style: ts.textStyle.caption),
                ],
              ),
          if (!widget.readonly && selected?.value != null)
            Padding(
              padding: EdgeInsets.only(top: ts.spacing.sm),
              child: Text(
                '${selected!.date}: ${selected.value}',
                style: ts.textStyle.caption,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  const _HeatmapPainter({
    required this.weeks,
    required this.maximum,
    required this.selected,
    required this.labels,
    required this.ts,
    required this.direction,
    required this.onSelect,
  });
  final List<List<CommonHeatmapCell>> weeks;
  final double maximum;
  final String? selected;
  final Map<String, String> labels;
  final TS ts;
  final TextDirection direction;
  final ValueChanged<CommonHeatmapCell>? onSelect;
  Rect _rect(int column, int row) => Rect.fromLTWH(
    column * (ts.sizing.iconMd + ts.spacing.xs),
    ts.sizing.controlSm + row * (ts.sizing.iconMd + ts.spacing.xs),
    ts.sizing.iconMd,
    ts.sizing.iconMd,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    for (var column = 0; column < weeks.length; column++) {
      final first = weeks[column]
          .where((cell) => cell.date.endsWith('-01'))
          .firstOrNull;
      if (first != null || column == 0) {
        final month = (first ?? weeks[column].first).date.substring(5, 7);
        final text = TextPainter(
          text: TextSpan(
            text: '${int.parse(month)}月',
            style: ts.textStyle.micro,
          ),
          textDirection: direction,
        )..layout();
        text.paint(
          canvas,
          Offset(
            _rect(column, 0).left,
            (ts.sizing.controlSm - text.height) / 2,
          ),
        );
      }
      for (var row = 0; row < 7; row++) {
        final cell = weeks[column][row];
        final rect = _rect(column, row);
        final shape = RRect.fromRectAndRadius(
          rect.deflate(ts.border.widthHairline / 2),
          Radius.circular(ts.radius.xs),
        );
        if (cell.value == null) {
          canvas.drawRRect(
            shape,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = ts.border.widthHairline
              ..color = ts.colors.divider,
          );
        } else {
          canvas.drawRRect(
            shape,
            paint
              ..style = PaintingStyle.fill
              ..color = cell.value == 0
                  ? ts.colors.surfaceVariant
                  : cell.value! / maximum < 0.5
                  ? ts.colors.primarySoft
                  : ts.colors.primary,
          );
        }
        if (cell.date == selected && cell.value != null) {
          canvas.drawRRect(
            shape,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = ts.border.widthStrong
              ..color = ts.colors.primary,
          );
        }
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (_) => [
        for (var column = 0; column < weeks.length; column++)
          for (var row = 0; row < 7; row++)
            CustomPainterSemantics(
              key: ValueKey(weeks[column][row].date),
              rect: _rect(column, row),
              properties: SemanticsProperties(
                textDirection: direction,
                label:
                    '${weeks[column][row].date}: ${weeks[column][row].value ?? '缺失'}${labels[weeks[column][row].date] == null ? '' : ' ${labels[weeks[column][row].date]}'}',
                button: onSelect != null && weeks[column][row].value != null,
                selected: weeks[column][row].date == selected,
                onTap: onSelect == null || weeks[column][row].value == null
                    ? null
                    : () => onSelect!(weeks[column][row]),
              ),
            ),
      ];
  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      weeks != oldDelegate.weeks ||
      maximum != oldDelegate.maximum ||
      selected != oldDelegate.selected ||
      ts != oldDelegate.ts ||
      direction != oldDelegate.direction;
  @override
  bool shouldRebuildSemantics(covariant _HeatmapPainter oldDelegate) =>
      shouldRepaint(oldDelegate) ||
      !mapEquals(labels, oldDelegate.labels) ||
      (onSelect == null) != (oldDelegate.onSelect == null);
}
