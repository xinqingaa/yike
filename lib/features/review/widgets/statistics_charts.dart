import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/motion/chart_value.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../focus/focus_models.dart';
import '../models/review_period.dart';
import '../logic/review_statistics.dart';
import 'period_picker.dart';
import 'review_labels.dart';

class StatisticsTrend extends StatelessWidget {
  const StatisticsTrend({
    super.key,
    required this.periods,
    required this.source,
    required this.selection,
    required this.card,
    required this.onSelected,
    required this.onInspect,
  });
  final List<ReviewSelection> periods;
  final List<FocusRecordView> source;
  final ReviewSelection selection;
  final AppDataCard card;
  final ValueChanged<ReviewSelection> onSelected;
  final VoidCallback onInspect;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final values = [
      for (final period in periods)
        PeriodMetrics(
          source,
          period.first,
          period.last,
          mode: selection.mode,
        ).seconds,
    ];
    final maxValue = math.max(7500, values.fold<num>(0, math.max));
    return Semantics(
      label:
          '${selection.month ? '6个月' : '8周'}专注趋势，选中${reviewPeriodLabel(selection)}',
      explicitChildNodes: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < periods.length; i++)
            Expanded(
              child: DataCardTarget(
                key: ValueKey(dayId(periods[i].first)),
                card: card,
                onShow: onInspect,
                content: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviewPeriodLabel(periods[i]),
                      style: ts.textStyle.subtitle,
                    ),
                    SizedBox(height: ts.spacing.sm),
                    Text(durationLabel(values[i]), style: ts.textStyle.content),
                  ],
                ),
                builder: (context, show, open) => CommonPressableSurface(
                  selected: periods[i].first == selection.first,
                  onPressed: () => onSelected(
                    periods[i].copyWith(
                      mode: selection.mode,
                      clearMode: selection.mode == null,
                    ),
                  ),
                  onLongPress: show,
                  child: Semantics(
                    label:
                        '${reviewPeriodLabel(periods[i])}，${durationLabel(values[i])}',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: ts.spacing.xs),
                      child: Column(
                        children: [
                          SizedBox(
                            height: ts.layout.chartPlotHeight,
                            child: ChartValue(
                              value: values[i] / maxValue,
                              period: selection.first,
                              filter: selection.mode,
                              builder: (context, fraction) => CustomPaint(
                                size: Size.infinite,
                                painter: _BarPainter(
                                  ts,
                                  fraction,
                                  block: 1500 / maxValue,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: ts.spacing.sm),
                          SizedBox(
                            height:
                                MediaQuery.textScalerOf(
                                  context,
                                ).scale(ts.textStyle.micro.fontSize!) *
                                (ts.textStyle.micro.height ?? 1) *
                                2,
                            child: Text(
                              selection.month
                                  ? '${periods[i].first.month}月'
                                  : '${periods[i].first.month}/${periods[i].first.day}',
                              style: ts.textStyle.micro.copyWith(
                                letterSpacing: 0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            height:
                                MediaQuery.textScalerOf(
                                  context,
                                ).scale(ts.textStyle.micro.fontSize!) *
                                (ts.textStyle.micro.height ?? 1),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                periods[i].first == selection.first
                                    ? '本期'
                                    : ' ',
                                style: ts.textStyle.micro.copyWith(
                                  color: ts.colors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.ts, this.fraction, {this.block = 0, this.hour = false});
  final TS ts;
  final double fraction, block;
  final bool hour;
  @override
  void paint(Canvas canvas, Size size) {
    final water = ts.pack.id.endsWith('water'),
        sundial = ts.pack.id.endsWith('sundial');
    final width = size.width * (hour ? .7 : .8),
        height = size.height * fraction.clamp(0, 1);
    final rect = Rect.fromLTWH(
      (size.width - width) / 2,
      size.height - height,
      width,
      height,
    );
    final paint = Paint()..color = ts.colors.primary;
    if (water) {
      final radius = Radius.circular(width / 2);
      if (!hour) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left, 0, width, size.height),
            radius,
          ),
          paint..color = ts.colors.primarySoft,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        paint..color = ts.colors.primary,
      );
      if (!hour && height > 0) {
        canvas.drawLine(
          Offset(rect.left + width * .25, rect.top + ts.spacing.xs),
          Offset(rect.left + width * .25, rect.bottom - ts.spacing.xs),
          paint
            ..color = ts.colors.surface.withValues(alpha: ts.opacity.pressed)
            ..strokeWidth = ts.border.widthStrong,
        );
      }
    } else if (sundial) {
      if (height > 0) {
        final path = Path()
          ..moveTo(rect.left, rect.top + math.min(ts.spacing.xs, height))
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawShadow(path, ts.colors.primary, ts.spacing.xs, true);
        canvas.drawPath(path, paint..color = ts.colors.primarySoft);
        canvas.drawLine(
          rect.topLeft,
          rect.topRight,
          paint
            ..color = ts.colors.primary
            ..strokeWidth = ts.border.widthStrong,
        );
      }
    } else {
      canvas.drawRect(rect, paint);
      if (!hour && block > 0) {
        for (var n = 1; n * block < fraction; n++) {
          final y = size.height * (1 - n * block);
          canvas.drawLine(
            Offset(rect.left, y),
            Offset(rect.right, y),
            paint
              ..color = ts.colors.surface
              ..strokeWidth = ts.border.widthHairline,
          );
        }
      }
    }
    if (height == 0) {
      canvas.drawLine(
        Offset(rect.left, size.height),
        Offset(rect.right, size.height),
        paint
          ..color = ts.colors.border
          ..strokeWidth = ts.border.widthHairline,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.ts != ts || old.fraction != fraction || old.block != block;
}

class TypeDistribution extends StatelessWidget {
  const TypeDistribution({
    super.key,
    required this.metrics,
    required this.selected,
    required this.onSelected,
    required this.period,
  });
  final Object period;
  final PeriodMetrics metrics;
  final TimerMode? selected;
  final ValueChanged<TimerMode> onSelected;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), total = metrics.seconds;
    final values = [
      for (final mode in TimerMode.values) metrics.forMode(mode).toDouble(),
    ];
    return Column(
      children: [
        SizedBox.square(
          dimension: ts.layout.chartPlotHeight,
          child: GestureDetector(
            onTapUp: (details) {
              final size = ts.layout.chartPlotHeight,
                  offset = details.localPosition - Offset(size / 2, size / 2);
              if (total <= 0 ||
                  offset.distance < size * .25 ||
                  offset.distance > size * .5) {
                return;
              }
              var angle =
                      (math.atan2(offset.dy, offset.dx) + math.pi / 2) %
                      (2 * math.pi),
                  sum = 0.0;
              for (var i = 0; i < values.length; i++) {
                sum += values[i] / total * math.pi * 2;
                if (angle < sum) {
                  onSelected(TimerMode.values[i]);
                  break;
                }
              }
            },
            child: ExcludeSemantics(
              child: ChartValue(
                value: 1,
                period: period,
                filter: null,
                builder: (context, reveal) => CustomPaint(
                  painter: _RingPainter(ts, values, selected, reveal),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: ts.spacing.sm),
        for (final mode in TimerMode.values)
          _TypeLegendRow(
            mode: mode,
            color: _typeColor(ts, mode.index),
            selected: selected == mode,
            seconds: metrics.forMode(mode),
            total: total,
            onPressed: () => onSelected(mode),
          ),
      ],
    );
  }
}

class _TypeLegendRow extends StatelessWidget {
  const _TypeLegendRow({
    required this.mode,
    required this.color,
    required this.selected,
    required this.seconds,
    required this.total,
    required this.onPressed,
  });
  final TimerMode mode;
  final Color color;
  final bool selected;
  final num seconds, total;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final row = CommonPressableSurface(
      selected: selected,
      onPressed: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ts.sizing.touch),
        child: Padding(
          padding: EdgeInsets.all(ts.spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: ts.spacing.smPlus,
                height: ts.spacing.smPlus,
                margin: EdgeInsets.only(right: ts.spacing.sm),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Text(modeLabel(mode), style: ts.textStyle.content),
              SizedBox(width: ts.spacing.sm),
              Expanded(
                child: Text(
                  '${durationLabel(seconds, compact: true)} · ${total == 0 ? 0 : (seconds / total * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: ts.textStyle.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return selected
        ? CommonGlassSurface(
            borderRadius: BorderRadius.circular(ts.radius.md),
            tint: color.withValues(alpha: ts.opacity.pressed),
            child: row,
          )
        : row;
  }
}

Color _typeColor(TS ts, int index) => ts.chartTypeColors[index];

class _RingPainter extends CustomPainter {
  _RingPainter(this.ts, this.values, this.selected, this.reveal);
  final double reveal;
  final TS ts;
  final List<double> values;
  final TimerMode? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(size.width * .12),
        stroke = size.width * .17;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = ts.colors.border;
    canvas.drawOval(rect, paint);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2 * reveal;
      if (sweep > 0) {
        final active = selected == null || selected!.index == i;
        paint
          ..color = _typeColor(
            ts,
            i,
          ).withValues(alpha: active ? 1 : ts.opacity.disabled)
          ..strokeCap = ts.pack.id.endsWith('water')
              ? StrokeCap.round
              : StrokeCap.butt;
        final gap = math.min(.08, sweep * .25);
        if (ts.pack.id.endsWith('sundial')) {
          canvas.drawArc(
            rect.shift(Offset(ts.spacing.xxs, ts.spacing.xxs)),
            start + gap / 2,
            sweep - gap,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..color = ts.colors.primarySoft
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, ts.spacing.xs),
          );
        }
        canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
        if (ts.pack.id.endsWith('water')) {
          canvas.drawArc(
            rect.deflate(stroke * .25),
            start + gap / 2,
            sweep - gap,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = ts.border.widthHairline
              ..color = ts.colors.surface.withValues(alpha: ts.opacity.pressed),
          );
        }
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ts != ts ||
      old.selected != selected ||
      old.reveal != reveal ||
      !listEquals(old.values, values);
}

class HourDistribution extends StatelessWidget {
  const HourDistribution({
    super.key,
    required this.values,
    required this.card,
    required this.onInspect,
    required this.period,
    this.mode,
  });
  final Object period;
  final TimerMode? mode;
  final List<num> values;
  final AppDataCard card;
  final VoidCallback onInspect;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), maxValue = values.fold<num>(0, math.max);
    final peaks = [
      for (var i = 0; i < 24; i++)
        if (maxValue > 0 && values[i] == maxValue) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '24小时开始时段，按开始时间统计',
          explicitChildNodes: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 24; i++)
                Expanded(
                  child: DataCardTarget(
                    card: card,
                    onShow: onInspect,
                    content: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$i:00–${i + 1}:00', style: ts.textStyle.subtitle),
                        Text(
                          durationLabel(values[i]),
                          style: ts.textStyle.content,
                        ),
                      ],
                    ),
                    builder: (context, show, open) => CommonPressableSurface(
                      onPressed: show,
                      onLongPress: show,
                      child: Semantics(
                        label: '$i点开始，${durationLabel(values[i])}',
                        child: SizedBox(
                          height: ts.layout.chartPlotHeight,
                          child: ChartValue(
                            value: maxValue == 0 ? 0 : values[i] / maxValue,
                            period: period,
                            filter: mode,
                            builder: (context, fraction) => CustomPaint(
                              size: Size.infinite,
                              painter: _BarPainter(ts, fraction, hour: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: ts.spacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final label in ['0', '6', '12', '18', '23'])
              Text(label, style: ts.textStyle.micro),
          ],
        ),
        SizedBox(height: ts.spacing.sm),
        Text(
          peaks.isEmpty
              ? '按开始时间统计'
              : peaks.length > 3
              ? '多个时段并列最多 · 按开始时间'
              : '${peaks.join('、')}点开始最多 · 按开始时间',
          style: ts.textStyle.caption,
        ),
      ],
    );
  }
}
