import 'dart:math' as math;
import '../../../common/time.dart';
import '../../focus/focus_models.dart';
import '../../habits/habit_models.dart';
import '../models/review_period.dart';

String recordIdentity(FocusRecordView record) => record.sessionId.isEmpty
    ? '${record.date}/${record.time}/${record.mode}'
    : record.sessionId;

class PeriodMetrics {
  PeriodMetrics(
    Iterable<FocusRecordView> source,
    this.first,
    this.last, {
    TimerMode? mode,
  }) : records = List.unmodifiable(
         source.where(
           (r) =>
               r.date.compareTo(dayId(first)) >= 0 &&
               r.date.compareTo(dayId(last)) <= 0 &&
               (mode == null || r.mode == mode),
         ),
       );
  final DateTime first, last;
  final List<FocusRecordView> records;
  num get seconds => records.fold<num>(0, (sum, r) => sum + r.seconds);
  int get sessions => records.map(recordIdentity).toSet().length;
  int get days =>
      records.where((r) => r.seconds > 0).map((r) => r.date).toSet().length;
  num get longest {
    final totals = <String, num>{};
    for (final r in records) {
      totals.update(
        recordIdentity(r),
        (v) => v + r.seconds,
        ifAbsent: () => r.seconds,
      );
    }
    return totals.values.fold<num>(0, math.max);
  }

  double get average =>
      seconds / math.max(1, last.difference(first).inDays + 1);
  List<num> get hours {
    final values = List<num>.filled(24, 0);
    for (final r in records) {
      values[int.parse(r.time.split(':').first)] += r.seconds;
    }
    return values;
  }

  num forMode(TimerMode mode) => records
      .where((r) => r.mode == mode)
      .fold<num>(0, (sum, r) => sum + r.seconds);
}

class PeriodComparison {
  PeriodComparison(
    ReviewSelection selection,
    DateTime today,
    Iterable<FocusRecordView> records,
  ) {
    final end = selection.last.isAfter(today) ? dayOnly(today) : selection.last;
    current = PeriodMetrics(
      records,
      selection.first,
      end,
      mode: selection.mode,
    );
    final prior = selection.shift(-1);
    final count = end.difference(selection.first).inDays + 1;
    final priorEnd = selection.last.isAfter(today)
        ? prior.first.add(Duration(days: count - 1))
        : prior.last;
    previous = PeriodMetrics(
      records,
      prior.first,
      priorEnd.isAfter(prior.last) ? prior.last : priorEnd,
      mode: selection.mode,
    );
  }
  late final PeriodMetrics current, previous;
}

class HabitPeriodProgress {
  HabitPeriodProgress(this.habit, ReviewSelection selection, DateTime today) {
    final first = dayId(selection.first),
        end = dayId(selection.last.isAfter(today) ? today : selection.last);
    completed = habit.dates
        .where((d) => d.compareTo(first) >= 0 && d.compareTo(end) <= 0)
        .length;
    final start = first.compareTo(habit.created) < 0 ? habit.created : first;
    var through = end;
    if (habit.archivedOn != null && habit.archivedOn!.compareTo(through) <= 0) {
      through = dayId(
        DateTime.parse(habit.archivedOn!).subtract(const Duration(days: 1)),
      );
    }
    target = habit.weekly
        ? (selection.month ? null : habit.goal)
        : math.max(
            0,
            dayOnly(
                  DateTime.parse(through),
                ).difference(dayOnly(DateTime.parse(start))).inDays +
                1,
          );
  }
  final HabitViewData habit;
  late final int completed;
  late final int? target;
}

/// A stable window only moves when the selected period leaves it.
class TrendWindow {
  TrendWindow(ReviewSelection selection, DateTime today)
    : end = ReviewSelection(anchor: today, month: selection.month);
  ReviewSelection end;
  List<ReviewSelection> periods(ReviewSelection selected) {
    if (end.month != selected.month) end = selected;
    final count = selected.month ? 6 : 8;
    final start = end.shift(1 - count).first;
    if (selected.first.isBefore(start) || selected.first.isAfter(end.first)) {
      end = selected;
    }
    return List.generate(count, (i) => end.shift(i + 1 - count));
  }
}
