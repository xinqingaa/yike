import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/state/local_value.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../theme/ts.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';
import '../logic/review_statistics.dart';
import '../models/review_period.dart';
import '../widgets/period_controls.dart';
import '../widgets/focus_year_plot.dart';
import '../widgets/statistics_charts.dart';
import '../widgets/review_labels.dart';

String overviewDuration(num seconds) => durationLabel(
  seconds >= 60 ? (seconds ~/ 60) * 60 : seconds,
  compact: true,
);
String _delta(num value, {bool days = false}) => value == 0
    ? '与上期持平'
    : '${value > 0 ? '+' : '−'}${days ? '${value.abs().toInt()}天' : overviewDuration(value.abs())}';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key, this.initial});
  final ReviewSelection? initial;
  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage>
    with TickerProviderStateMixin {
  late TabController _types;
  Duration? _tabDuration;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TS.of(context).motion.durationNormal;
    if (_tabDuration == duration) return;
    final previous = _tabDuration == null ? null : _types;
    final mode = ref.read(_selection).mode;
    previous?.removeListener(_typeChanged);
    _types = TabController(
      length: 4,
      vsync: this,
      initialIndex: mode == null ? 0 : mode.index + 1,
      animationDuration: duration,
    );
    _types.addListener(_typeChanged);
    _tabDuration = duration;
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _typeChanged() {
    final mode = _types.index == 0 ? null : TimerMode.values[_types.index - 1];
    final selected = ref.read(_selection);
    if (selected.mode != mode) {
      _update(selected.copyWith(mode: mode, clearMode: mode == null));
    }
  }

  late final _selection = localValueProvider(
    widget.initial ?? ReviewSelection(anchor: ref.read(todayProvider)),
  );
  final _card = AppDataCard();
  TrendWindow? _window;
  @override
  void dispose() {
    _types.dispose();
    _card.dispose();
    super.dispose();
  }

  void _update(ReviewSelection next) {
    _card.close();
    if (next.month != ref.read(_selection).month) {
      _window = TrendWindow(next, ref.read(todayProvider));
    }
    ref.read(_selection.notifier).set(next);
    final index = next.mode == null ? 0 : next.mode!.index + 1;
    if (_types.index != index) {
      _types.animateTo(
        index,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : TS.of(context).motion.durationNormal,
      );
    }
  }

  void _toggle(TimerMode mode) {
    final value = ref.read(_selection);
    _update(
      value.mode == mode
          ? value.copyWith(clearMode: true)
          : value.copyWith(mode: mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context),
        today = ref.watch(todayProvider),
        selected = ref.watch(_selection);
    final source = ref.watch(focusRecordsProvider),
        habits = ref.watch(habitsProvider);
    final comparison = PeriodComparison(selected, today, source),
        metrics = comparison.current,
        previous = comparison.previous;
    final all = PeriodMetrics(source, selected.first, selected.last);
    final current = !selected.last.isBefore(today);
    _window ??= TrendWindow(selected, today);
    final periods = _window!.periods(selected);
    final reference = current ? '较上期同期' : '较上期';
    final first = previous.first, last = previous.last;
    return Scaffold(
      appBar: const CommonAppBar(
        title: '统计',
        showBack: true,
        background: CommonAppBarSurface.transparent,
      ),
      body: SafeArea(
        top: false,
        child: YikePageWidth(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) _card.close();
              return false;
            },
            child: SingleChildScrollView(
              key: const PageStorageKey('statistics-scroll'),
              padding: EdgeInsets.all(ts.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReviewPeriodControls(
                    selection: selected,
                    today: today,
                    onChanged: _update,
                  ),
                  SizedBox(height: ts.spacing.md),
                  CommonSecondaryTabs(
                    controller: _types,
                    grow: true,
                    items: const [
                      CommonTabItem(value: 'all', label: '全部'),
                      CommonTabItem(value: 'pomodoro', label: '番茄钟'),
                      CommonTabItem(value: 'stopwatch', label: '正计时'),
                      CommonTabItem(value: 'countdown', label: '倒计时'),
                    ],
                  ),
                  SizedBox(height: ts.spacing.lg),
                  Semantics(
                    label: '比较范围 ${dayId(first)} 至 ${dayId(last)}',
                    child: Text(
                      '$reference · ${first.month}/${first.day}–${last.month}/${last.day}',
                      style: ts.textStyle.micro,
                    ),
                  ),
                  SizedBox(height: ts.spacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metric(
                        '总专注',
                        metrics.seconds,
                        _delta(metrics.seconds - previous.seconds),
                      ),
                      SizedBox(width: ts.spacing.md),
                      _metric(
                        '日均专注${current ? ' · 截至今天' : ''}',
                        metrics.average,
                        _delta(metrics.average - previous.average),
                      ),
                    ],
                  ),
                  SizedBox(height: ts.spacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metric(
                        '专注天数',
                        metrics.days,
                        _delta(metrics.days - previous.days, days: true),
                        days: true,
                      ),
                      SizedBox(width: ts.spacing.md),
                      _metric(
                        '最长单次 · 本期内',
                        metrics.longest,
                        _delta(metrics.longest - previous.longest),
                      ),
                    ],
                  ),
                  _section('专注趋势', trailing: selected.month ? '6个月' : '8周'),
                  StatisticsTrend(
                    key: ValueKey(('trend', selected.month)),
                    periods: periods,
                    source: source,
                    selection: selected,
                    card: _card,
                    onSelected: _update,
                    onInspect: () => ref.read(feedbackServiceProvider).select(),
                  ),
                  _section('类型占比', trailing: '本期全部类型'),
                  TypeDistribution(
                    metrics: all,
                    period: (selected.month, selected.first),
                    selected: selected.mode,
                    onSelected: _toggle,
                  ),
                  _section('开始时段'),
                  HourDistribution(
                    key: ValueKey((
                      'hours',
                      selected.month,
                      dayId(selected.first),
                    )),
                    values: metrics.hours,
                    period: (selected.month, selected.first),
                    mode: selected.mode,
                    card: _card,
                    onInspect: () => ref.read(feedbackServiceProvider).select(),
                  ),
                  _section('习惯完成', trailing: current ? null : '按当前规则'),
                  if (habits.where((h) => !h.archived).isEmpty)
                    Text('暂无进行中的习惯', style: ts.textStyle.caption),
                  for (final habit in habits.where((h) => !h.archived))
                    _habit(habit, selected, today),
                  _section(
                    '最近一年专注',
                    trailing: selected.mode == null
                        ? null
                        : '仅${modeLabel(selected.mode!)}',
                  ),
                  FocusYearPlot(
                    records: source,
                    today: today,
                    card: _card,
                    mode: selected.mode,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, num value, String delta, {bool days = false}) {
    final ts = TS.of(context);
    return Expanded(
      child: Semantics(
        label: '$label，${days ? '$value天' : durationLabel(value)}，$delta',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ts.textStyle.caption),
            SizedBox(height: ts.spacing.xs),
            Text(
              days ? '$value天' : overviewDuration(value),
              style: ts.textStyle.numericContent,
            ),
            SizedBox(height: ts.spacing.xs),
            Text(delta, style: ts.textStyle.micro),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, {String? trailing}) {
    final ts = TS.of(context);
    return Padding(
      padding: EdgeInsets.only(top: ts.spacing.lg, bottom: ts.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CommonDivider(),
          SizedBox(height: ts.spacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: ts.textStyle.subtitle)),
              if (trailing != null) ...[
                SizedBox(width: ts.spacing.sm),
                Flexible(
                  child: Text(
                    trailing,
                    style: ts.textStyle.micro,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _habit(HabitViewData habit, ReviewSelection selected, DateTime today) {
    final ts = TS.of(context),
        progress = HabitPeriodProgress(habit, selected, today);
    return Padding(
      padding: EdgeInsets.only(bottom: ts.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(habit.name, style: ts.textStyle.content)),
              SizedBox(width: ts.spacing.sm),
              Flexible(
                child: Text(
                  progress.target == null
                      ? '完成${progress.completed}次 · 每周${habit.goal}次'
                      : '${progress.completed}/${progress.target}${habit.weekly ? '次' : '天'}',
                  style: ts.textStyle.caption,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          SizedBox(height: ts.spacing.sm),
          Semantics(
            label: '本期每日完成记录',
            explicitChildNodes: true,
            child: Wrap(
              spacing: ts.spacing.xs,
              runSpacing: ts.spacing.xs,
              children: [
                for (
                  var date = selected.first;
                  !date.isAfter(selected.last);
                  date = date.add(const Duration(days: 1))
                )
                  HabitDayTarget(
                    habit: habit,
                    date: dayId(date),
                    today: dayId(today),
                    card: _card,
                    builder: (context, show, selectedDay) => Semantics(
                      label:
                          '${habit.name}，${dayId(date)}，${habit.dates.contains(dayId(date))
                              ? '已完成'
                              : date.isAfter(today)
                              ? '未来日期'
                              : dayId(date).compareTo(habit.created) < 0
                              ? '创建前'
                              : '未打卡'}',
                      child: CommonPressableSurface(
                        onPressed: show,
                        onLongPress: show,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(ts.radius.xs),
                        ),
                        child: CommonHeatmapBlock(
                          cellKey: ValueKey(
                            'habit-progress-${habit.id}-${dayId(date)}',
                          ),
                          size: ts.spacing.smPlus,
                          color: habitDayColor(
                            ts,
                            done: habit.dates.contains(dayId(date)),
                            inactive:
                                date.isAfter(today) ||
                                dayId(date).compareTo(habit.created) < 0,
                            archived:
                                habit.archivedOn != null &&
                                dayId(date).compareTo(habit.archivedOn!) >= 0,
                            selected: selectedDay,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
