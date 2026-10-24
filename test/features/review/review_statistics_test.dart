import 'package:flutter_test/flutter_test.dart';
import 'package:yike/features/focus/focus_models.dart';
import 'package:yike/features/habits/habit_models.dart';
import 'package:yike/features/review/logic/review_statistics.dart';
import 'package:yike/features/review/providers/review_presentation.dart';

FocusRecordView record(
  String day,
  num seconds, {
  String id = 'session',
  String time = '23:59',
  TimerMode mode = TimerMode.stopwatch,
}) => FocusRecordView(
  date: day,
  time: time,
  seconds: seconds,
  sessionId: id,
  mode: mode,
);
void main() {
  test('cross-day metrics sum only selected parts and count one session', () {
    final source = [
      record('2026-10-18', 30.25),
      record('2026-10-19', 60.75),
      record('2026-10-19', 35, id: 'second'),
    ];
    final all = PeriodMetrics(
      source,
      DateTime.utc(2026, 10, 18),
      DateTime.utc(2026, 10, 19),
    );
    expect(all.seconds, 126);
    expect(all.sessions, 2);
    expect(all.days, 2);
    expect(all.longest, 91);
    expect(all.hours[23], 126);
    final one = PeriodMetrics(
      source,
      DateTime.utc(2026, 10, 19),
      DateTime.utc(2026, 10, 19),
    );
    expect(one.seconds, 95.75);
    expect(one.longest, 60.75);
    expect(one.sessions, 2);
    expect(one.hours[23], 95.75);
  });
  test(
    'type selection changes focus facts without filtering habits or type choices',
    () {
      final selected = ReviewSelection(
        anchor: DateTime.utc(2026, 10, 24),
        mode: TimerMode.pomodoro,
      );
      final result = reviewSummaryFor(
        selected,
        [
          record('2026-10-20', 35, mode: TimerMode.pomodoro),
          record('2026-10-20', 35, id: 'two'),
        ],
        [
          HabitViewData(
            id: 'h',
            name: '阅读',
            created: '2026-01-01',
            dates: {'2026-10-20'},
          ),
        ],
      );
      expect(result.seconds, 35);
      expect(result.allRecords, hasLength(2));
      expect(result.checkins, 1);
      expect(selected.shift(-1).mode, TimerMode.pomodoro);
      expect(selected.copyWith(month: true).mode, TimerMode.pomodoro);
      expect(selected.copyWith(clearMode: true).mode, isNull);
    },
  );
  test('current week compares the same elapsed natural days', () {
    final comparison = PeriodComparison(
      ReviewSelection(anchor: DateTime.utc(2026, 10, 21)),
      DateTime.utc(2026, 10, 21),
      [
        record('2026-10-12', 100),
        record('2026-10-15', 200, id: 'outside'),
        record('2026-10-20', 90, id: 'now'),
      ],
    );
    expect(comparison.current.last, DateTime.utc(2026, 10, 21));
    expect(comparison.previous.last, DateTime.utc(2026, 10, 14));
    expect(comparison.previous.seconds, 100);
    expect(comparison.current.average, 30);
  });
  test(
    'partial month clamps to shorter prior month and uses actual denominators',
    () {
      final comparison = PeriodComparison(
        ReviewSelection(anchor: DateTime.utc(2026, 3, 31), month: true),
        DateTime.utc(2026, 3, 31),
        [record('2026-02-28', 280), record('2026-03-31', 310, id: 'march')],
      );
      // On the final day this is a complete month; February remains 28 days.
      expect(comparison.previous.last, DateTime.utc(2026, 2, 28));
      expect(comparison.current.average, 10);
      expect(comparison.previous.average, 10);
      final partial = PeriodComparison(
        ReviewSelection(anchor: DateTime.utc(2026, 3, 30), month: true),
        DateTime.utc(2026, 3, 30),
        [],
      );
      expect(partial.previous.last, DateTime.utc(2026, 2, 28));
      expect(partial.current.last, DateTime.utc(2026, 3, 30));
    },
  );
  test(
    'historical periods compare complete periods and empty metrics stay finite',
    () {
      final comparison = PeriodComparison(
        ReviewSelection(anchor: DateTime.utc(2026, 9, 2), month: true),
        DateTime.utc(2026, 10, 24),
        [],
      );
      expect(comparison.current.last, DateTime.utc(2026, 9, 30));
      expect(comparison.previous.last, DateTime.utc(2026, 8, 31));
      expect(comparison.current.average, 0);
      expect(comparison.current.longest, 0);
    },
  );
  test(
    'weekly habit monthly view does not invent a fractional denominator',
    () {
      final habit = HabitViewData(
        id: 'h',
        name: '阅读',
        weekly: true,
        goal: 3,
        created: '2026-10-22',
        dates: {'2026-10-22', '2026-10-23'},
      );
      final week = HabitPeriodProgress(
        habit,
        ReviewSelection(anchor: DateTime.utc(2026, 10, 24)),
        DateTime.utc(2026, 10, 24),
      );
      final month = HabitPeriodProgress(
        habit,
        ReviewSelection(anchor: DateTime.utc(2026, 10, 24), month: true),
        DateTime.utc(2026, 10, 24),
      );
      expect(week.target, 3);
      expect(month.target, isNull);
      expect(month.completed, 2);
    },
  );
  test(
    'daily targets exclude dates before creation, after today, and current archive',
    () {
      final selection = ReviewSelection(anchor: DateTime.utc(2026, 10, 24));
      final habit = HabitViewData(
        id: 'h',
        name: '阅读',
        created: '2026-10-22',
        archivedOn: '2026-10-24',
      );
      expect(
        HabitPeriodProgress(
          habit,
          selection,
          DateTime.utc(2026, 10, 24),
        ).target,
        2,
      );
      expect(
        HabitPeriodProgress(
          habit.copyWith(restore: true),
          selection,
          DateTime.utc(2026, 10, 24),
        ).target,
        3,
      );
      expect(
        HabitPeriodProgress(
          habit,
          selection.shift(-1),
          DateTime.utc(2026, 10, 24),
        ).target,
        0,
      );
    },
  );
  test(
    'trend window stays still on inner selections and follows old periods',
    () {
      final selected = ReviewSelection(anchor: DateTime.utc(2026, 10, 24));
      final window = TrendWindow(selected, DateTime.utc(2026, 10, 24));
      final first = window.periods(selected);
      expect(first, hasLength(8));
      expect(
        window.periods(first[2]).map((p) => p.first),
        first.map((p) => p.first),
      );
      final old = selected.shift(-20);
      expect(window.periods(old).last.first, old.first);
      expect(window.periods(selected).last.first, selected.first);
    },
  );
}
