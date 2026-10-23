import '../../../common/motion/content_transition.dart';
import '../../../common/motion/page_transition.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';
import '../providers/review_presentation.dart';
import '../../../common/time.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/state/local_value.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../theme/ts.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/review_labels.dart';
import '../widgets/period_picker.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});
  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final _detailOpen = localValueProvider(false);
  @override
  Widget build(BuildContext context) {
    final opening = ref.watch(_detailOpen);
    final ts = TS.of(context);
    final selected = ref.watch(reviewSelectionProvider);
    final today = ref.watch(todayProvider);
    final from = dayId(selected.first);
    final summary = ref.watch(reviewSummaryProvider);
    final records = summary.records, checkins = summary.checkins;
    final total = summary.seconds;
    final current = !selected.last.isBefore(
      selected.month ? DateTime.utc(today.year, today.month) : weekStart(today),
    );
    void update(ReviewSelection value) {
      ref.read(reviewSelectionProvider.notifier).select(value);
    }

    void shift(int amount) => update(
      selected.copyWith(
        anchor: selected.month
            ? DateTime.utc(selected.anchor.year, selected.anchor.month + amount)
            : selected.anchor.add(Duration(days: 7 * amount)),
        clear: true,
      ),
    );
    Future<void> open(String date) async {
      if (opening || ref.read(_detailOpen)) return;
      ref.read(_detailOpen.notifier).set(true);
      update(selected.copyWith(lastViewedDate: date));
      try {
        await AppPop.sheet<void>(
          title: '每日记录',
          material: CommonSurfaceMaterial.glass,
          size: const SheetSizeConfig(maxHeight: SheetDimension.fraction(1)),
          child: DayDetailSheet(
            initial: date,
            first: selected.first,
            last: selected.last.isAfter(today) ? today : selected.last,
          ),
        );
      } finally {
        if (mounted) ref.read(_detailOpen.notifier).set(false);
      }
    }

    Future<void> choosePeriod() async {
      if (ref.read(_detailOpen)) return;
      ref.read(_detailOpen.notifier).set(true);
      try {
        final next = await pickReviewPeriod(selected);
        if (next != null && mounted) update(next);
      } finally {
        if (mounted) ref.read(_detailOpen.notifier).set(false);
      }
    }

    return ListView(
      key: const PageStorageKey('review-scroll'),
      padding: EdgeInsets.all(ts.spacing.lg),
      children: [
        Row(
          children: [
            Expanded(child: Text('回顾', style: ts.textStyle.headline)),
            CommonIconButton(
              name: CommonIconName.calendarCurrent,
              label: '返回当前周期',
              disabled: current,
              variant: CommonIconButtonVariant.text,
              onPressed: () =>
                  update(selected.copyWith(anchor: today, clear: true)),
            ),
          ],
        ),
        SizedBox(height: ts.spacing.md),
        Row(
          children: [
            SizedBox(
              width: ts.sizing.controlSm * 2 + ts.spacing.sm,
              child: YikeSelectionBar(
                size: CommonPrimaryTabsSize.sm,
                items: const [
                  CommonTabItem(value: 'week', label: '周'),
                  CommonTabItem(value: 'month', label: '月'),
                ],
                value: selected.month ? 'month' : 'week',
                onSelected: (value) => update(
                  ReviewSelection(
                    month: value == 'month',
                    anchor: selected.lastViewedDate == null
                        ? current
                              ? today
                              : selected.anchor
                        : DateTime.parse(selected.lastViewedDate!),
                  ),
                ),
              ),
            ),
            SizedBox(width: ts.spacing.sm),
            Expanded(
              child: Row(
                children: [
                  CommonIconButton(
                    name: CommonIconName.chevronLeft,
                    label: '上一期',
                    variant: CommonIconButtonVariant.text,
                    onPressed: () => shift(-1),
                  ),
                  Expanded(
                    child: MotionPage<(bool, String)>(
                      value: (selected.month, from),
                      direction: (before, after) => before.$1 != after.$1
                          ? (after.$1 ? 1 : -1)
                          : after.$2.compareTo(before.$2).toDouble().sign,
                      resize: false,
                      child: CommonPressableSurface(
                        key: const ValueKey('review-period-picker'),
                        onPressed: choosePeriod,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: ts.sizing.touch,
                          ),
                          child: Center(
                            child: Text(
                              reviewPeriodLabel(selected),
                              textAlign: TextAlign.center,
                              style: ts.textStyle.caption,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  CommonIconButton(
                    name: CommonIconName.chevronRight,
                    label: '下一期',
                    disabled: current,
                    variant: CommonIconButtonVariant.text,
                    onPressed: () => shift(1),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: ts.spacing.md),
        CommonDivider(),
        SizedBox(height: ts.spacing.md),
        MotionPage<(bool, String)>(
          value: (selected.month, from),
          direction: (before, after) => before.$1 != after.$1
              ? (after.$1 ? 1 : -1)
              : after.$2.compareTo(before.$2).toDouble().sign,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _summary(ts, '专注', durationLabel(total), flex: 2),
                  _summary(
                    ts,
                    selected.month ? '专注天数' : '专注次数',
                    selected.month
                        ? '${records.map((r) => r.date).toSet().length} 天'
                        : '${records.map(recordIdentity).toSet().length} 次',
                  ),
                  _summary(ts, '打卡', '$checkins 次'),
                ],
              ),
              SizedBox(height: ts.spacing.md),
              CommonDivider(),
              SizedBox(height: ts.spacing.md),
              MotionExpand(
                expanded: records.isEmpty && checkins == 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      selected.month ? '这一月还没有记录' : '这一周还没有记录',
                      style: ts.textStyle.subtitle,
                    ),
                    SizedBox(height: ts.spacing.xs),
                    Text('从底部“专注”或“打卡”开始记录。', style: ts.textStyle.caption),
                    SizedBox(height: ts.spacing.md),
                  ],
                ),
              ),
              if (selected.month)
                CommonMonthCalendar(
                  month: from.substring(0, 7),
                  today: dayId(today),
                  showHeader: false,
                  customDayAppearance: true,
                  dayShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      ts.pack.id.endsWith('sundial')
                          ? ts.radius.xs
                          : ts.radius.full,
                    ),
                  ),
                  label: '本月每日专注',
                  disabledDates: {
                    for (
                      var day = selected.first;
                      !day.isAfter(selected.last);
                      day = day.add(const Duration(days: 1))
                    )
                      if (day.isAfter(today)) dayId(day),
                  },
                  onChanged: open,
                  dayBuilder: (context, day) => _MonthDay(
                    day: day,
                    checkins: ref
                        .watch(habitsProvider)
                        .where((habit) => habit.dates.contains(day.date))
                        .length,
                    seconds: records
                        .where((r) => r.date == day.date)
                        .fold<num>(0, (sum, r) => sum + r.seconds),
                  ),
                )
              else
                _WeekChart(
                  selection: selected,
                  today: today,
                  records: records,
                  checkins: ref
                      .watch(habitsProvider)
                      .expand((habit) => habit.dates)
                      .toList(),
                  onSelected: open,
                ),
              MotionExpand(
                expanded: total > 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: ts.spacing.md),
                    Text('按类型', style: ts.textStyle.subtitle),
                    for (final mode in TimerMode.values) ...[
                      SizedBox(height: ts.spacing.md),
                      Row(
                        children: [
                          Text(
                            modeLabel(mode),
                            style: ts.textStyle.content.copyWith(
                              color: ts.colors.onSurfaceMuted,
                            ),
                          ),
                          SizedBox(width: ts.spacing.sm),
                          Expanded(
                            child: Text(
                              '${records.where((r) => r.mode == mode).map(recordIdentity).toSet().length} 次 · ${durationLabel(records.where((r) => r.mode == mode).fold<num>(0, (sum, r) => sum + r.seconds))}',
                              style: ts.textStyle.caption,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ts.spacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ts.radius.full),
                        child: SizedBox(
                          height: ts.sizing.progressTrack,
                          child: Stack(
                            children: [
                              ColoredBox(
                                color: ts.colors.border,
                                child: const SizedBox.expand(),
                              ),
                              FractionallySizedBox(
                                widthFactor: total == 0
                                    ? 0
                                    : records
                                              .where((r) => r.mode == mode)
                                              .fold<num>(
                                                0,
                                                (sum, r) => sum + r.seconds,
                                              ) /
                                          total,
                                child: ColoredBox(
                                  color: ts.colors.primary,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(TS ts, String label, String value, {int flex = 1}) =>
      Expanded(
        flex: flex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts.textStyle.caption),
            SizedBox(height: ts.spacing.xs),
            Text(value, style: ts.textStyle.subtitle),
          ],
        ),
      );
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({
    required this.selection,
    required this.today,
    required this.records,
    required this.checkins,
    required this.onSelected,
  });
  final ReviewSelection selection;
  final DateTime today;
  final List<FocusRecordView> records;
  final List<String> checkins;
  final ValueChanged<String> onSelected;
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
                    return CommonPressableSurface(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ts.pack.id.endsWith('water')
                              ? ts.radius.full
                              : ts.radius.xs,
                        ),
                      ),
                      key: ValueKey('review-day-${dayId(date)}'),
                      onPressed: future ? null : () => onSelected(dayId(date)),
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
                                ),
                              ),
                              SizedBox(height: ts.spacing.xs),
                              Text(
                                '周${const ['一', '二', '三', '四', '五', '六', '日'][i]}',
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
  });
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
              child: FractionallySizedBox(
                heightFactor: fraction.clamp(0, 1),
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
                            colors: [ts.colors.primarySoft, ts.colors.primary],
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

class _MonthDay extends StatelessWidget {
  const _MonthDay({
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
    final level = seconds == 0
        ? 0
        : seconds <= 1800
        ? 1
        : seconds <= 5400
        ? 2
        : 3;
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
        graph,
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
