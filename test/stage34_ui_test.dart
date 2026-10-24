import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/semantics.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/common/motion/chart_value.dart';
import 'package:yike/features/review/widgets/day_data_card.dart';
import 'package:yike/features/review/widgets/day_detail_sheet.dart';
import 'package:yike/features/review/widgets/focus_year_plot.dart';
import 'package:yike/features/review/widgets/statistics_charts.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/widgets/lap_panel.dart';
import 'package:yike/features/review/pages/statistics_page.dart';
import 'package:yike/features/review/providers/review_presentation.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/habits/widgets/habit_day_target.dart';
import 'package:yike/theme/ts.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'yike_ui_test.dart' show pumpYike, navigateTab;
import 'support/pump_presentation.dart';

void main() {
  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets('$theme lap panel owns controls and retains finished laps', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 16, 12);
      final app = await pumpYike(tester, theme: theme, clock: () => now);
      await tester.tap(find.text('正计时'));
      await pumpPresentation(tester);
      await tester.tap(find.text('开始计时'));
      await pumpPresentation(tester);
      expect(find.text('计圈'), findsNothing);
      expect(find.text('暂停'), findsOneWidget);
      expect(find.text('结束并记录'), findsOneWidget);
      expect(find.text('取消计时'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stopwatch-laps-entry')));
      await pumpPresentation(tester);
      expect(find.byType(LapPanel), findsOneWidget);
      final panel = tester.getRect(find.byType(LapPanel));
      expect(panel.width, closeTo(390, .1));
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 3));
        await tester.tap(find.byKey(const ValueKey('lap-panel-lap')));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(app.read(focusViewProvider).laps, [3, 6, 9]);
      await pumpPresentation(tester);
      expect(find.text('最快'), findsOneWidget);
      expect(find.text('最慢'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lap-panel-pause')));
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).paused, isTrue);
      expect(
        find.descendant(of: find.byType(LapPanel), matching: find.text('继续')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: find.byType(LapPanel), matching: find.text('取消计时')),
      );
      await pumpPresentation(tester);
      await tester.tap(find.text('继续保留'));
      await pumpPresentation(tester);
      expect(find.byType(LapPanel), findsOneWidget);
      expect(app.read(focusViewProvider).laps, hasLength(3));
      await tester.tap(find.byKey(const ValueKey('lap-panel-pause')));
      await pumpPresentation(tester);
      now = now.add(const Duration(seconds: 3590));
      app.read(focusActionsProvider).calibrate();
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).finished, isTrue);
      expect(find.text('末段 · 未计圈'), findsOneWidget);
      expect(find.byType(LapPanel), findsOneWidget);
      expect(app.read(focusViewProvider).laps, hasLength(3));
      await tester.tap(
        find.descendant(of: find.byType(LapPanel), matching: find.text('完成')),
      );
      await pumpPresentation(tester);
      expect(find.byType(LapPanel), findsNothing);
      expect(app.read(focusViewProvider).ready, isTrue);
      expect(app.read(focusRecordsProvider), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'lap flight caps parallel marks, rejects zero laps and stops for reduced motion',
    (tester) async {
      var now = DateTime.utc(2026, 10, 16, 12);
      final app = await pumpYike(tester, clock: () => now);
      app.read(focusActionsProvider).switchMode(TimerMode.stopwatch);
      app.read(focusActionsProvider).start();
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('stopwatch-laps-entry')));
      await pumpPresentation(tester);
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(seconds: 2));
        await tester.tap(find.byKey(const ValueKey('lap-panel-lap')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 15));
      }
      expect(app.read(focusViewProvider).laps, hasLength(5));
      final marks = find.byKey(const ValueKey('lap-flight-mark'));
      expect(marks.evaluate().length, inInclusiveRange(1, 3));
      await tester.tap(find.byKey(const ValueKey('lap-panel-lap')));
      await tester.pump();
      expect(app.read(focusViewProvider).laps, hasLength(5));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.pump();
      expect(marks, findsNothing);
      now = now.add(const Duration(seconds: 2));
      await tester.tap(find.byKey(const ValueKey('lap-panel-lap')));
      await tester.pump();
      await tester.pump();
      expect(app.read(focusViewProvider).laps, hasLength(6));
      expect(marks, findsNothing);
      await tester.tap(find.byTooltip('关闭计圈'));
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('stopwatch-laps-entry')));
      await pumpPresentation(tester);
      expect(marks, findsNothing);
      expect(
        app.read(localDataProvider).data.focus.session!.laps,
        hasLength(6),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'review filter survives navigation and stats use an independent selection',
    (tester) async {
      final app = await pumpYike(
        tester,
        records: const [
          FocusRecordView(
            date: '2026-10-16',
            time: '12:00',
            seconds: 1500,
            mode: TimerMode.pomodoro,
            sessionId: 'p',
          ),
          FocusRecordView(
            date: '2026-10-16',
            time: '14:00',
            seconds: 300,
            mode: TimerMode.stopwatch,
            sessionId: 's',
          ),
        ],
      );
      await navigateTab(tester, '回顾');
      await tester.ensureVisible(find.text('番茄钟').last);
      await tester.tap(find.text('番茄钟').last);
      await pumpPresentation(tester);
      expect(app.read(reviewSelectionProvider).mode, TimerMode.pomodoro);
      expect(app.read(reviewSummaryProvider).seconds, 1500);
      await navigateTab(tester, '专注');
      await navigateTab(tester, '回顾');
      expect(app.read(reviewSelectionProvider).mode, TimerMode.pomodoro);
      await tester.ensureVisible(find.byTooltip('统计'));
      await tester.tap(find.byTooltip('统计'));
      await pumpPresentation(tester);
      expect(find.byType(StatisticsPage), findsOneWidget);
      await tester.tap(find.text('全部').last);
      await pumpPresentation(tester);
      final ring = find
          .descendant(
            of: find.byType(TypeDistribution),
            matching: find.byType(GestureDetector),
          )
          .first;
      await tester.ensureVisible(ring);
      await pumpPresentation(tester);
      final rect = tester.getRect(ring);
      await tester.tapAt(rect.center + Offset(rect.width * .38, 0));
      await pumpPresentation(tester);
      expect(
        tester.widget<TypeDistribution>(find.byType(TypeDistribution)).selected,
        TimerMode.pomodoro,
      );
      final tabs = find.descendant(
        of: find.byType(StatisticsPage),
        matching: find.byType(CommonSecondaryTabs),
      );
      await tester.ensureVisible(tabs);
      await pumpPresentation(tester);
      expect(tester.widget<CommonSecondaryTabs>(tabs).controller!.index, 1);

      await tester.tap(find.byTooltip('返回'));
      await pumpPresentation(tester);
      expect(app.read(reviewSelectionProvider).mode, TimerMode.pomodoro);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'day inspection opens filtered detail and closes on root navigation',
    (tester) async {
      final app = await pumpYike(tester);
      await navigateTab(tester, '回顾');
      await tester.longPress(
        find.byKey(const ValueKey('review-day-2026-10-16')),
      );
      await pumpPresentation(tester);
      expect(find.text('专注 0 分钟 · 0次'), findsOneWidget);
      expect(find.text('打卡 0次'), findsOneWidget);
      expect(find.bySemanticsLabel('专注 0 分钟，专注次数 0次'), findsOneWidget);
      expect(find.text('查看当日记录'), findsOneWidget);
      await tester.ensureVisible(find.text('查看当日记录'));
      await tester.tap(find.text('查看当日记录'));
      await pumpPresentation(tester);
      expect(find.text('这一天没有记录'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
      await tester.longPress(
        find.byKey(const ValueKey('review-day-2026-10-16')),
      );
      await pumpPresentation(tester);
      await navigateTab(tester, '专注');
      expect(find.text('查看当日记录'), findsNothing);
      expect(app.read(reviewSelectionProvider).lastViewedDate, '2026-10-16');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'habit year cell inspects without editing facts and scroll closes card',
    (tester) async {
      final app = await pumpYike(tester);
      app.read(habitsProvider.notifier).toggle('habit-water', '2026-10-16');
      await pumpPresentation(tester);
      final dates = app.read(habitsProvider).first.dates;
      await navigateTab(tester, '打卡');
      await tester.tap(find.byKey(const ValueKey('habit-detail-habit-water')));
      await pumpPresentation(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('habit-day-2026-10-16')),
      );
      await tester.tap(find.byKey(const ValueKey('habit-day-2026-10-16')));
      await pumpPresentation(tester);
      expect(find.textContaining('已完成 ·'), findsOneWidget);
      final card = find
          .ancestor(
            of: find.textContaining('当周完成'),
            matching: find.byType(TapRegion),
          )
          .first;
      final rect = tester.getRect(card);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(844));
      expect(app.read(habitsProvider).first.dates, dates);
      await tester.drag(
        find.byKey(const ValueKey('habit-year-scroll')),
        const Offset(80, 0),
      );
      await pumpPresentation(tester);
      expect(find.textContaining('已完成 ·'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'review filtering keeps the chart at the same position even for an empty type',
    (tester) async {
      await pumpYike(
        tester,
        records: const [
          FocusRecordView(
            date: '2026-10-16',
            time: '12:00',
            seconds: 1500,
            mode: TimerMode.pomodoro,
            sessionId: 'p',
          ),
        ],
      );
      await navigateTab(tester, '回顾');
      final day = find.byKey(const ValueKey('review-day-2026-10-16'));
      final top = tester.getTopLeft(day).dy;
      for (final type in ['番茄钟', '正计时', '倒计时', '倒计时']) {
        await tester.tap(find.text(type).last);
        await pumpPresentation(tester);
        expect(tester.getTopLeft(day).dy, top);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'week and month offer detail while year dates only inspect the same menu',
    (tester) async {
      await pumpYike(tester);
      await navigateTab(tester, '回顾');
      Future<void> check(Finder date) async {
        await tester.ensureVisible(date);
        await tester.tap(date);
        await pumpPresentation(tester);
        expect(find.byType(DayDetailSheet), findsNothing);
        expect(find.text('查看当日记录'), findsOneWidget);
        await tester.ensureVisible(find.text('查看当日记录'));
        await tester.tap(find.text('查看当日记录'));
        await pumpPresentation(tester);
        expect(find.byType(DayDetailSheet), findsOneWidget);
        await tester.tap(find.byTooltip('关闭'));
        await pumpPresentation(tester);
        await tester.longPress(date);
        await pumpPresentation(tester);
        expect(find.byType(DayDetailSheet), findsNothing);
        expect(find.text('查看当日记录'), findsOneWidget);
        await tester.ensureVisible(find.text('查看当日记录'));
        await tester.tap(find.text('查看当日记录'));
        await pumpPresentation(tester);
        expect(find.byType(DayDetailSheet), findsOneWidget);
        await tester.tap(find.byTooltip('关闭'));
        await pumpPresentation(tester);
      }

      await check(find.byKey(const ValueKey('review-day-2026-10-16')));
      await tester.tap(find.text('月'));
      await pumpPresentation(tester);
      await check(
        find.byWidgetPredicate(
          (w) => w is ReviewDayTarget && w.date == '2026-10-16',
        ),
      );
      Scrollable.of(
        tester.element(find.byType(CommonMonthCalendar)),
      ).position.jumpTo(0);
      await pumpPresentation(tester);
      await tester.tap(find.byTooltip('统计'));
      await pumpPresentation(tester);
      final date = find.descendant(
        of: find.byType(FocusYearPlot),
        matching: find.byWidgetPredicate(
          (w) => w is ReviewDayTarget && w.date == '2026-10-16',
        ),
      );
      await tester.ensureVisible(date);
      for (final long in [false, true]) {
        if (long) {
          await tester.longPress(date);
        } else {
          await tester.tap(date);
        }
        await pumpPresentation(tester);
        expect(find.text('10月16日 周五'), findsOneWidget);
        expect(find.text('查看当日记录'), findsNothing);
        expect(find.byType(DayDetailSheet), findsNothing);
        final rect = tester.getRect(
          find
              .ancestor(
                of: find.text('10月16日 周五'),
                matching: find.byType(TapRegion),
              )
              .first,
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(844));
        await tester.tapAt(const Offset(2, 2));
        await pumpPresentation(tester);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'statistics retains tab and chart state and habit dots inspect without changing facts',
    (tester) async {
      await pumpYike(tester);
      await navigateTab(tester, '回顾');
      await tester.tap(find.byTooltip('统计'));
      await pumpPresentation(tester);
      final tabs = find.descendant(
        of: find.byType(StatisticsPage),
        matching: find.byType(CommonSecondaryTabs),
      );
      final controller = tester.widget<CommonSecondaryTabs>(tabs).controller!;
      await tester.tap(find.descendant(of: tabs, matching: find.text('正计时')));
      await pumpPresentation(tester);
      expect(controller.index, 2);
      final chart = tester.state(find.byType(ChartValue).first);
      final dot = find.byKey(
        const ValueKey('habit-progress-habit-water-2026-10-16'),
      );
      await tester.ensureVisible(dot);
      await pumpPresentation(tester);
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(dot)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        tester
            .getSemantics(dot)
            .getSemanticsData()
            .hasAction(SemanticsAction.longPress),
        isTrue,
      );
      semantics.dispose();
      await tester.tap(dot);
      await pumpPresentation(tester);
      expect(find.textContaining('当周完成'), findsOneWidget);
      expect(find.byType(DayDetailSheet), findsNothing);
      expect(find.text('查看当日记录'), findsNothing);
      await tester.drag(find.text('习惯完成'), const Offset(0, 8));
      await pumpPresentation(tester);
      expect(find.textContaining('当周完成'), findsNothing);
      await tester.longPress(dot);
      await pumpPresentation(tester);
      expect(find.textContaining('当周完成'), findsOneWidget);
      await tester.ensureVisible(tabs);
      await pumpPresentation(tester);
      expect(
        tester.widget<CommonSecondaryTabs>(tabs).controller,
        same(controller),
      );
      expect(controller.index, 2);
      expect(tester.state(find.byType(ChartValue).first), same(chart));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'habit cards use the tapped date across creation, missed and completed days',
    (tester) async {
      final app = await pumpYike(tester);
      app.read(habitsProvider.notifier).replace([
        HabitViewData(
          id: 'habit-water',
          name: '阅读',
          created: '2026-10-14',
          dates: const {'2026-10-15'},
          checkins: {
            '2026-10-15': HabitCheckin(
              id: 'done',
              at: DateTime.utc(2026, 10, 15, 20, 8),
            ),
          },
        ),
      ]);
      await navigateTab(tester, '回顾');
      await tester.tap(find.byTooltip('统计'));
      await pumpPresentation(tester);
      BoxDecoration progressDecoration(String day) =>
          tester
                  .widget<DecoratedBox>(
                    find.byKey(
                      ValueKey('habit-progress-habit-water-$day'),
                      skipOffstage: false,
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final ts = TS.of(tester.element(find.byType(StatisticsPage)));
      expect(progressDecoration('2026-10-13').color, ts.heatmapOutside);
      expect(progressDecoration('2026-10-13').border, isNull);
      expect(progressDecoration('2026-10-14').color, ts.heatmapEmpty);
      expect(progressDecoration('2026-10-15').color, ts.colors.primary);
      expect(progressDecoration('2026-10-17').color, ts.heatmapOutside);
      await tester.ensureVisible(find.byType(FocusYearPlot));
      final focusColors = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(FocusYearPlot),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color);
      expect(focusColors, isNotEmpty);
      expect(focusColors.contains(Colors.transparent), isFalse);
      await tester.ensureVisible(find.text('少'));
      final ramp = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find
                  .ancestor(of: find.text('少'), matching: find.byType(Row))
                  .first,
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color!)
          .toList();
      expect(ramp, hasLength(4));
      double strength(Color color) {
        final bg = ts.colors.background;
        return (color.r - bg.r).abs() +
            (color.g - bg.g).abs() +
            (color.b - bg.b).abs();
      }

      for (var i = 0; i < 3; i++) {
        expect(strength(ramp[i + 1]), greaterThan(strength(ramp[i])));
      }
      Future<void> inspect(String prefix) async {
        for (final entry in {
          '2026-10-13': '当天尚未创建此习惯',
          '2026-10-14': '未打卡',
          '2026-10-15': '已完成 · 20:08',
          '2026-10-16': '未打卡',
        }.entries) {
          final cell = find.byKey(ValueKey('$prefix${entry.key}'));
          await tester.ensureVisible(cell);
          await tester.tap(cell);
          await pumpPresentation(tester);
          expect(
            find.descendant(
              of: find.byType(HabitDayCard),
              matching: find.text(entry.value),
            ),
            findsOneWidget,
          );
          expect(
            find.text('创建于 2026-10-14'),
            entry.key == '2026-10-13' ? findsOneWidget : findsNothing,
          );
          expect(
            find.textContaining('当周完成'),
            entry.key == '2026-10-13' ? findsNothing : findsOneWidget,
          );
          await tester.tapAt(const Offset(2, 2));
          await pumpPresentation(tester);
        }
      }

      await inspect('habit-progress-habit-water-');
      await tester.tap(find.byTooltip('返回'));
      await pumpPresentation(tester);
      await navigateTab(tester, '打卡');
      await tester.tap(find.byKey(const ValueKey('habit-detail-habit-water')));
      await pumpPresentation(tester);
      await inspect('habit-day-');
      expect(app.read(habitsProvider).single.dates, {'2026-10-15'});
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow large text panel and statistics keep controls reachable',
    (tester) async {
      var now = DateTime.utc(2026, 10, 16, 12);
      final app = await pumpYike(
        tester,
        size: const Size(320, 700),
        clock: () => now,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      app.read(focusActionsProvider).switchMode(TimerMode.stopwatch);
      app.read(focusActionsProvider).start();
      now = now.add(const Duration(seconds: 20));
      app.read(focusActionsProvider).lap();
      now = now.add(const Duration(seconds: 20));
      app.read(focusActionsProvider).lap();
      await pumpPresentation(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('stopwatch-laps-entry')),
      );
      await tester.tap(find.byKey(const ValueKey('stopwatch-laps-entry')));
      await pumpPresentation(tester);
      expect(find.byKey(const ValueKey('lap-panel-pause')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭计圈'));
      await pumpPresentation(tester);
      await navigateTab(tester, '回顾');
      await tester.tap(find.byTooltip('统计'));
      await pumpPresentation(tester);
      final scroll = find
          .descendant(
            of: find.byType(StatisticsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 8; i++) {
        await tester.drag(scroll, const Offset(0, -260));
        await pumpPresentation(tester);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('最近一年专注'), findsOneWidget);
    },
  );
}
