import '../../focus/focus.dart';
import '../../habits/habits.dart';
import '../providers/review_presentation.dart';
import '../../../app/navigation.dart';
import '../../../common/time.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unified_popups/unified_popups.dart'
    show SheetSizeConfig, SheetDimension;
import '../../../common/state/local_value.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/dial.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../theme/ts.dart';

String recordIdentity(FocusRecordView record) => record.sessionId.isEmpty
    ? '${record.date}/${record.time}/${record.mode}'
    : record.sessionId;

String modeLabel(TimerMode mode) => const ['番茄钟', '正计时', '倒计时'][mode.index];

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = TS.of(context);
    final selected = ref.watch(reviewSelectionProvider);
    final today = ref.watch(todayProvider);
    final from = dayId(selected.first), through = dayId(selected.last);
    final records = ref
        .watch(focusRecordsProvider)
        .where(
          (r) => r.date.compareTo(from) >= 0 && r.date.compareTo(through) <= 0,
        )
        .toList();
    final checkins = ref
        .watch(habitsProvider)
        .expand((h) => h.dates)
        .where((d) => d.compareTo(from) >= 0 && d.compareTo(through) <= 0)
        .length;
    final total = records.fold<num>(0, (sum, r) => sum + r.seconds);
    final current = !selected.last.isBefore(
      selected.month ? DateTime.utc(today.year, today.month) : weekStart(today),
    );
    void update(ReviewSelection value) =>
        ref.read(reviewSelectionProvider.notifier).select(value);
    void shift(int amount) => update(
      selected.copyWith(
        anchor: selected.month
            ? DateTime.utc(selected.anchor.year, selected.anchor.month + amount)
            : selected.anchor.add(Duration(days: 7 * amount)),
        clear: true,
      ),
    );
    void open(String date) {
      update(selected.copyWith(selected: date));
      AppPop.sheet<void>(
        context,
        title: selected.month ? '本月' : '本周',
        material: CommonSurfaceMaterial.glass,
        size: SheetSizeConfig(
          height: SheetDimension.fraction(ts.sizing.panelMedium),
        ),
        builder: (_, handle) => DayDetailSheet(
          initial: date,
          first: selected.first,
          last: selected.last.isAfter(today) ? today : selected.last,
        ),
      );
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
              width: ts.sizing.controlMd * 2 + ts.spacing.lg + ts.spacing.xs,
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
                    anchor: selected.selected == null
                        ? current
                              ? today
                              : selected.anchor
                        : DateTime.parse(selected.selected!),
                  ),
                ),
              ),
            ),
            CommonIconButton(
              name: CommonIconName.chevronLeft,
              label: '上一期',
              variant: CommonIconButtonVariant.text,
              onPressed: () => shift(-1),
            ),
            Expanded(
              child: Text(
                selected.month
                    ? '${selected.anchor.year} 年 ${selected.anchor.month} 月'
                    : '${selected.first.month}月${selected.first.day}日 – ${selected.last.month == selected.first.month ? '' : '${selected.last.month}月'}${selected.last.day}日',
                textAlign: TextAlign.center,
                style: ts.textStyle.caption,
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
        SizedBox(height: ts.spacing.md),
        CommonDivider(),
        SizedBox(height: ts.spacing.md),
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
        if (records.isEmpty && checkins == 0)
          Padding(
            padding: EdgeInsets.symmetric(vertical: ts.spacing.lg),
            child: Column(
              children: [
                YikeDial(width: ts.sizing.brand, brand: true, progress: 0),
                SizedBox(height: ts.spacing.md),
                Text(
                  selected.month ? '这一月还没有专注记录' : '这一周还没有专注记录',
                  style: ts.textStyle.subtitle,
                ),
                SizedBox(height: ts.spacing.md),
                SizedBox(
                  width: ts.sizing.actionMinInline,
                  child: CommonButton(
                    label: '去专注',
                    kind: CommonButtonKind.accent,
                    shape: CommonButtonShape.pill,
                    onPressed: () => ref.read(rootTabProvider.notifier).set(0),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (selected.month)
            CommonMonthCalendar(
              month: from.substring(0, 7),
              today: dayId(today),
              value: selected.selected,
              showHeader: false,
              customDayAppearance: true,
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
              onSelected: open,
            ),
          if (total > 0) ...[
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
                  const Spacer(),
                  Text(
                    '${records.where((r) => r.mode == mode).map(recordIdentity).toSet().length} 次 · ${durationLabel(records.where((r) => r.mode == mode).fold<num>(0, (sum, r) => sum + r.seconds))}',
                    style: ts.textStyle.caption,
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
                        widthFactor:
                            records
                                .where((r) => r.mode == mode)
                                .fold<num>(0, (sum, r) => sum + r.seconds) /
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
        ],
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
    required this.onSelected,
  });
  final ReviewSelection selection;
  final DateTime today;
  final List<FocusRecordView> records;
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
          '每块 25 分钟 · 量程 ${maxSeconds % 60 == 0 ? maxSeconds ~/ 60 : (maxSeconds / 60).toStringAsFixed(1)} 分钟',
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
                    return InkWell(
                      onTap: future ? null : () => onSelected(dayId(date)),
                      child: Semantics(
                        label: '${dayId(date)}，${durationLabel(values[i])}',
                        selected: selection.selected == dayId(date),
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
                                  selected: selection.selected == dayId(date),
                                ),
                              ),
                              SizedBox(height: ts.spacing.xs),
                              Text(
                                const ['一', '二', '三', '四', '五', '六', '日'][i],
                                style: ts.textStyle.caption.copyWith(
                                  color: dayId(date) == dayId(today)
                                      ? ts.colors.primary
                                      : ts.colors.onSurfaceMuted,
                                ),
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
    required this.selected,
    required this.blockFraction,
  });
  final double fraction, blockFraction;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final water = ts.pack.id.endsWith('water');
    final sundial = ts.pack.id.endsWith('sundial');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: water ? ts.colors.surface : Colors.transparent,
        border: water || selected
            ? Border.fromBorderSide(
                selected ? ts.border.focus : ts.border.defaultBorder,
              )
            : null,
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
  const _MonthDay({required this.day, required this.seconds});
  final CommonCalendarDay day;
  final num seconds;
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
    return AspectRatio(
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
            if (day.selected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: mechanical || water
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    border: Border.fromBorderSide(ts.border.focus),
                    borderRadius: mechanical || water
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

class DayDetailSheet extends ConsumerStatefulWidget {
  const DayDetailSheet({
    super.key,
    required this.initial,
    required this.first,
    required this.last,
  });
  final String initial;
  final DateTime first, last;
  @override
  ConsumerState<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends ConsumerState<DayDetailSheet> {
  late final _selected = localValueProvider(widget.initial);
  @override
  Widget build(BuildContext context) {
    final date = ref.watch(_selected);
    final parsed = DateTime.parse(date);
    final records =
        ref.watch(focusRecordsProvider).where((r) => r.date == date).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    final habits = ref
        .watch(habitsProvider)
        .where((h) => h.dates.contains(date))
        .toList();
    final ts = TS.of(context);
    void shift(int delta) {
      final next = dayId(parsed.add(Duration(days: delta)));
      ref.read(_selected.notifier).set(next);
      ref
          .read(reviewSelectionProvider.notifier)
          .select(ref.read(reviewSelectionProvider).copyWith(selected: next));
    }

    return Column(
      children: [
        Expanded(
          child: CommonDataList(
            key: ValueKey(date),
            itemCount: records.length + 2,
            divided: false,
            surface: CommonDataListSurface.none,
            rounded: CommonDataListRounded.none,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: ts.spacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${parsed.month}月${parsed.day}日 周${const ['一', '二', '三', '四', '五', '六', '日'][parsed.weekday - 1]}',
                          style: ts.textStyle.subtitle,
                        ),
                      ),
                      Text(
                        durationLabel(
                          records.fold<num>(0, (sum, r) => sum + r.seconds),
                        ),
                        style: ts.textStyle.caption,
                      ),
                    ],
                  ),
                );
              }
              if (index == records.length + 1) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: ts.spacing.md),
                  child: Text(
                    habits.isNotEmpty
                        ? '打卡：${habits.map((h) => h.name).join('、')}'
                        : records.isEmpty
                        ? '这一天没有记录'
                        : '这一天没有打卡记录',
                    style: ts.textStyle.content,
                  ),
                );
              }
              final record = records[index - 1];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
                child: Row(
                  children: [
                    Text(record.time, style: ts.textStyle.caption),
                    SizedBox(width: ts.spacing.lg),
                    Text(modeLabel(record.mode), style: ts.textStyle.content),
                    const Spacer(),
                    Text(
                      durationLabel(record.seconds),
                      style: ts.textStyle.numericContent,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        CommonDivider(),
        Row(
          children: [
            Expanded(
              child: CommonButton(
                label: '‹  前一天',
                kind: CommonButtonKind.quiet,
                disabled: !parsed.isAfter(widget.first),
                onPressed: () => shift(-1),
              ),
            ),
            Expanded(
              child: CommonButton(
                label: '后一天  ›',
                kind: CommonButtonKind.quiet,
                disabled: !parsed.isBefore(widget.last),
                onPressed: () => shift(1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
