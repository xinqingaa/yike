import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/motion/page_transition.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../router/routes.dart';
import '../../../theme/ts.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';
import '../providers/review_presentation.dart';
import '../widgets/day_detail_sheet.dart';
import '../widgets/day_data_card.dart';
import '../widgets/period_controls.dart';
import '../widgets/review_charts.dart';
import '../widgets/review_labels.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});
  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final _card = AppDataCard();
  bool _opening = false;
  @override
  void dispose() {
    _card.dispose();
    super.dispose();
  }

  void _update(ReviewSelection value) {
    _card.close();
    ref.read(reviewSelectionProvider.notifier).select(value);
  }

  Future<void> _open(String date) async {
    if (!mounted ||
        _opening ||
        date.compareTo(dayId(ref.read(todayProvider))) > 0) {
      return;
    }
    _card.close();
    _opening = true;
    final selected = ref.read(reviewSelectionProvider),
        today = ref.read(todayProvider);
    _update(selected.copyWith(lastViewedDate: date));
    try {
      await AppPop.sheet<void>(
        title: '每日记录',
        material: CommonSurfaceMaterial.glass,
        size: const SheetSizeConfig(maxHeight: SheetDimension.fraction(1)),
        child: DayDetailSheet(
          initial: date,
          first: selected.first,
          last: selected.last.isAfter(today) ? today : selected.last,
          mode: selected.mode,
          onDateChanged: (next) {
            if (mounted) {
              _update(
                ref
                    .read(reviewSelectionProvider)
                    .copyWith(lastViewedDate: next),
              );
            }
          },
        ),
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), today = ref.watch(todayProvider);
    final selected = ref.watch(reviewSelectionProvider),
        summary = ref.watch(reviewSummaryProvider);
    final all = summary.allRecords, records = summary.records;
    final total = summary.seconds;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) _card.close();
        return false;
      },
      child: ListView(
        key: const PageStorageKey('review-scroll'),
        padding: EdgeInsets.all(ts.spacing.lg),
        children: [
          Row(
            children: [
              Expanded(child: Text('回顾', style: ts.textStyle.titleLg)),
              CommonIconButton(
                name: CommonIconName.chartColumn,
                label: '统计',
                variant: CommonIconButtonVariant.text,
                onPressed: () {
                  _card.close();
                  Navigator.of(context).pushNamed(
                    AppRoutes.statistics,
                    arguments: StatisticsRouteArguments(
                      anchor: selected.anchor,
                      month: selected.month,
                      mode: selected.mode?.name,
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: ts.spacing.md),
          ReviewPeriodControls(
            selection: selected,
            today: today,
            onChanged: _update,
          ),
          SizedBox(height: ts.spacing.lg),
          MotionPage<(bool, String)>(
            value: (selected.month, dayId(selected.first)),
            direction: (a, b) => a.$1 != b.$1
                ? (b.$1 ? 1 : -1)
                : b.$2.compareTo(a.$2).toDouble().sign,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summary(
                      ts,
                      selected.mode == null
                          ? '专注'
                          : '${modeLabel(selected.mode!)}专注',
                      durationLabel(total),
                      flex: 2,
                    ),
                    _summary(
                      ts,
                      selected.month ? '专注天数' : '专注次数',
                      selected.month
                          ? '${records.map((r) => r.date).toSet().length} 天'
                          : '${records.map(recordIdentity).toSet().length} 次',
                    ),
                    _summary(ts, '打卡', '${summary.checkins} 次'),
                  ],
                ),
                SizedBox(height: ts.spacing.lg),
                if (all.isEmpty && summary.checkins == 0) ...[
                  Text(
                    selected.month ? '这一月还没有记录' : '这一周还没有记录',
                    style: ts.textStyle.caption,
                  ),
                  SizedBox(height: ts.spacing.md),
                ],
                if (selected.month)
                  CommonMonthCalendar(
                    month: dayId(selected.first).substring(0, 7),
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
                    dayInteractionBuilder: (context, day, node, child) =>
                        ReviewDayTarget(
                          date: day.date,
                          card: _card,
                          mode: selected.mode,
                          enabled: !day.disabled,
                          focusNode: node,
                          onOpen: () => _open(day.date),
                          child: child,
                        ),
                    dayBuilder: (context, day) => ReviewMonthDay(
                      day: day,
                      checkins: ref
                          .watch(habitsProvider)
                          .where((h) => h.dates.contains(day.date))
                          .length,
                      seconds: records
                          .where((r) => r.date == day.date)
                          .fold<num>(0, (sum, r) => sum + r.seconds),
                    ),
                  )
                else
                  ReviewWeekChart(
                    selection: selected,
                    today: today,
                    records: records,
                    checkins: ref
                        .watch(habitsProvider)
                        .expand((h) => h.dates)
                        .toList(),
                    card: _card,
                    mode: selected.mode,
                    onSelected: _open,
                  ),
              ],
            ),
          ),
          SizedBox(height: ts.spacing.lg),
          Text('按类型', style: ts.textStyle.subtitle),
          for (final mode in TimerMode.values)
            Padding(
              padding: EdgeInsets.only(top: ts.spacing.sm),
              child: CommonPressableSurface(
                selected: selected.mode == mode,
                onPressed: () => _update(
                  selected.mode == mode
                      ? selected.copyWith(clearMode: true)
                      : selected.copyWith(mode: mode),
                ),
                child: _typeSurface(
                  ts,
                  mode,
                  selected.mode == mode,
                  Opacity(
                    opacity: selected.mode == null || selected.mode == mode
                        ? 1
                        : ts.opacity.disabled,
                    child: Padding(
                      padding: EdgeInsets.all(ts.spacing.sm),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                modeLabel(mode),
                                style: ts.textStyle.content.copyWith(
                                  color: selected.mode == mode
                                      ? ts.colors.primary
                                      : ts.colors.onSurface,
                                ),
                              ),
                              SizedBox(width: ts.spacing.sm),
                              Expanded(
                                child: Text(
                                  '${all.where((r) => r.mode == mode).map(recordIdentity).toSet().length}次 · ${durationLabel(all.where((r) => r.mode == mode).fold<num>(0, (sum, r) => sum + r.seconds), compact: true)}',
                                  style: ts.textStyle.caption,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: ts.spacing.xs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(ts.radius.full),
                            child: LinearProgressIndicator(
                              value: all.isEmpty
                                  ? 0
                                  : all
                                            .where((r) => r.mode == mode)
                                            .fold<num>(
                                              0,
                                              (sum, r) => sum + r.seconds,
                                            ) /
                                        all.fold<num>(
                                          0,
                                          (sum, r) => sum + r.seconds,
                                        ),
                              minHeight: ts.sizing.progressTrack,
                              backgroundColor: ts.colors.border,
                              color: selected.mode == mode
                                  ? ts.colors.primary
                                  : ts.colors.primary.withValues(
                                      alpha: ts.opacity.pressed + .3,
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

  Widget _typeSurface(TS ts, TimerMode mode, bool selected, Widget child) =>
      selected
      ? CommonGlassSurface(
          borderRadius: BorderRadius.circular(ts.radius.md),
          tint: ts.chartTypeColors[mode.index].withValues(
            alpha: ts.opacity.pressed,
          ),
          child: child,
        )
      : child;

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
