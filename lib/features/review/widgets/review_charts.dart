import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../common/time.dart';
import '../../../common/motion/chart_value.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../focus/focus.dart';
import '../logic/focus_duration_level.dart';
import '../providers/review_presentation.dart';
import 'day_data_card.dart';

class ReviewWeekChart extends StatelessWidget {
  const ReviewWeekChart({
    super.key,
    required this.selection,
    required this.today,
    required this.records,
    required this.checkins,
    required this.onSelected,
    required this.card,
    this.mode,
  });
  final ReviewSelection selection;
  final DateTime today;
  final List<FocusRecordView> records;
  final List<String> checkins;
  final ValueChanged<String> onSelected;
  final AppDataCard card;
  final TimerMode? mode;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final values = [
      for (var i = 0; i < 7; i++)
        records
            .where(
              (r) => r.date == dayId(selection.first.add(Duration(days: i))),
            )
            .fold<num>(0, (sum, r) => sum + r.seconds),
    ];
    final maxSeconds = math.max(7500, values.reduce(math.max));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${ts.pack.id.endsWith('mechanical') ? '每格 25 分钟 · ' : ''}单位：分钟 · 量程 ${maxSeconds % 60 == 0 ? maxSeconds ~/ 60 : (maxSeconds / 60).toStringAsFixed(1)} 分钟',
          style: ts.textStyle.caption,
        ),
        SizedBox(height: ts.spacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final date = selection.first.add(Duration(days: i));
                    final future = date.isAfter(today);
                    return IgnorePointer(
                      ignoring: future,
                      child: ReviewDayTarget(
                        enabled: !future,
                        date: dayId(date),
                        card: card,
                        mode: mode,
                        onOpen: () => onSelected(dayId(date)),
                        key: ValueKey('review-day-${dayId(date)}'),
                        child: IgnorePointer(
                          ignoring: future,
                          child: Semantics(
                            label: '${dayId(date)}，${durationLabel(values[i])}',
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: ts.spacing.xs,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    future
                                        ? '—'
                                        : values[i] == 0
                                        ? '0'
                                        : '${values[i] / 60 == values[i] ~/ 60 ? values[i] ~/ 60 : (values[i] / 60).toStringAsFixed(1)}',
                                    style: ts.textStyle.micro,
                                  ),
                                  SizedBox(height: ts.spacing.sm),
                                  SizedBox(
                                    height: ts.layout.chartPlotHeight,
                                    child: _WeekColumn(
                                      fraction: values[i] / maxSeconds,
                                      blockFraction: 1500 / maxSeconds,
                                      future: future,
                                      filter: mode,
                                      period: selection.first,
                                    ),
                                  ),
                                  SizedBox(height: ts.spacing.xs),
                                  Text(
                                    '周${weekdayLabels[i]}',
                                    style: ts.textStyle.caption.copyWith(
                                      color: dayId(date) == dayId(today)
                                          ? ts.colors.primary
                                          : ts.colors.onSurfaceMuted,
                                    ),
                                  ),
                                  SizedBox(height: ts.spacing.xs),
                                  Text(
                                    '${date.day}',
                                    maxLines: 1,
                                    style: ts.textStyle.micro,
                                  ),
                                  SizedBox(height: ts.spacing.xs),
                                  Text(
                                    checkins.contains(dayId(date))
                                        ? '${checkins.where((day) => day == dayId(date)).length}次'
                                        : ' ',
                                    style: ts.textStyle.micro.copyWith(
                                      color: ts.colors.primary,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.fraction,
    required this.blockFraction,
    required this.future,
    required this.filter,
    required this.period,
  });
  final Object? filter;
  final Object period;
  final double fraction, blockFraction;
  final bool future;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final water = ts.pack.id.endsWith('water');
    final sundial = ts.pack.id.endsWith('sundial');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: future ? Colors.transparent : ts.colors.surface,
        border: Border.fromBorderSide(ts.border.defaultBorder),
        borderRadius: BorderRadius.circular(
          water ? ts.radius.full : ts.radius.xs,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          water ? ts.radius.full : ts.radius.xs,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: ChartValue(
                value: fraction.clamp(0, 1),
                period: period,
                filter: filter,
                builder: (context, animated) => FractionallySizedBox(
                  heightFactor: animated,
                  widthFactor: sundial
                      ? .5
                      : water
                      ? 1
                      : .85,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: sundial ? null : ts.colors.primary,
                      gradient: sundial
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                ts.colors.primarySoft,
                                ts.colors.primary,
                              ],
                            )
                          : null,
                    ),
                    child: sundial
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: ColoredBox(
                              color: ts.colors.onSurface,
                              child: SizedBox(
                                height: ts.border.widthStrong,
                                width: double.infinity,
                              ),
                            ),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            if (!water && !sundial)
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    for (var i = 1; i * blockFraction < 1; i++)
                      Positioned(
                        bottom: constraints.maxHeight * i * blockFraction,
                        left: 0,
                        right: 0,
                        child: ColoredBox(
                          color: ts.colors.background,
                          child: SizedBox(height: ts.border.widthHairline),
                        ),
                      ),
                  ],
                ),
              ),
            if (water)
              Align(
                alignment: Alignment.bottomCenter,
                child: ColoredBox(
                  color: ts.colors.border,
                  child: SizedBox(
                    height: ts.border.widthHairline,
                    width: double.infinity,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ReviewMonthDay extends StatelessWidget {
  const ReviewMonthDay({
    super.key,
    required this.day,
    required this.seconds,
    required this.checkins,
  });
  final CommonCalendarDay day;
  final num seconds;
  final int checkins;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final mechanical = ts.pack.id.endsWith('mechanical'),
        water = ts.pack.id.endsWith('water');
    final level = focusDurationLevel(seconds);
    final glyph = mechanical
        ? [
            CommonIconName.yikeMechanicalCalendar,
            CommonIconName.yikeMechanicalFocusLow,
            CommonIconName.yikeMechanicalFocusMedium,
            CommonIconName.yikeMechanicalFocusHigh,
          ][level]
        : water
        ? [
            null,
            CommonIconName.yikeWaterFocusLow,
            CommonIconName.yikeWaterFocusMedium,
            CommonIconName.yikeWaterFocusHigh,
          ][level]
        : [
            null,
            CommonIconName.yikeSundialFocusLow,
            CommonIconName.yikeSundialFocusMedium,
            CommonIconName.yikeSundialFocusHigh,
          ][level];
    final graph = AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: EdgeInsets.all(ts.spacing.xs),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (glyph != null)
              Positioned.fill(
                child: FittedBox(
                  child: CommonIcon(
                    name: glyph,
                    dimension: ts.sizing.controlSm,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: water ? BoxShape.circle : BoxShape.rectangle,
                    border: Border.fromBorderSide(ts.border.defaultBorder),
                    borderRadius: water
                        ? null
                        : BorderRadius.circular(ts.radius.xs),
                  ),
                ),
              ),
            Text(
              '${int.parse(day.date.substring(8))}',
              style: ts.textStyle.micro.copyWith(
                color: ts.colors.onSurface,
                fontWeight: day.today ? FontWeight.bold : null,
              ),
            ),
            if (day.today)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CustomPaint(
                    size: Size(ts.sizing.stepDot * 2, ts.sizing.stepDot),
                    painter: _TodayMarker(ts),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationNormal,
          child: KeyedSubtree(
            key: ValueKey((day.date, level, ts.pack.id)),
            child: graph,
          ),
        ),
        SizedBox(
          height: ts.textStyle.micro.fontSize! * ts.textStyle.micro.height!,
          child: checkins > 0
              ? Text(
                  '$checkins次',
                  style: ts.textStyle.micro.copyWith(color: ts.colors.primary),
                )
              : null,
        ),
      ],
    );
  }
}

class _TodayMarker extends CustomPainter {
  const _TodayMarker(this.ts);
  final TS ts;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ts.colors.primary;
    if (ts.pack.id.endsWith('mechanical')) {
      paint
        ..strokeWidth = ts.border.widthStrong
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
    } else if (ts.pack.id.endsWith('water')) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 0)
          ..cubicTo(size.width, size.height, 0, size.height, size.width / 2, 0)
          ..close(),
        paint,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TodayMarker old) => old.ts != ts;
}
