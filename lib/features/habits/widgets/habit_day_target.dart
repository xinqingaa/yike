import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/time.dart';
import '../../../theme/ts.dart';
import '../models/habit_view.dart';

/// Read-only inspection shared by habit details and statistics, for tap and long press.
class HabitDayTarget extends ConsumerWidget {
  const HabitDayTarget({
    super.key,
    required this.habit,
    required this.date,
    required this.today,
    required this.card,
    required this.builder,
  });
  final HabitViewData habit;
  final String date, today;
  final AppDataCard card;
  final Widget Function(BuildContext, VoidCallback, bool) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DataCardTarget(
    card: card,
    onShow: () => ref.read(feedbackServiceProvider).select(scope: 'habits'),
    content: (_) => HabitDayCard(habit: habit, date: date, today: today),
    builder: builder,
  );
}

class HabitDayCard extends StatelessWidget {
  const HabitDayCard({
    super.key,
    required this.habit,
    required this.date,
    required this.today,
  });
  final HabitViewData habit;
  final String date, today;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context), day = dayOnly(DateTime.parse(date));
    final before = date.compareTo(habit.created) < 0,
        future = date.compareTo(today) > 0;
    final done = habit.dates.contains(date),
        archived =
            habit.archivedOn != null && date.compareTo(habit.archivedOn!) >= 0;
    final status = done
        ? '已完成'
        : before
        ? '当天尚未创建此习惯'
        : future
        ? '范围外 · 未来日期'
        : archived
        ? '归档期间'
        : '未打卡';
    final checkin = habit.checkins[date];
    final time = checkin == null
        ? ''
        : ' · ${checkin.at.hour.toString().padLeft(2, '0')}:${checkin.at.minute.toString().padLeft(2, '0')}';
    final start = weekStart(day), weekEnd = start.add(const Duration(days: 6));
    var end = weekEnd.isAfter(DateTime.parse(today))
        ? dayOnly(DateTime.parse(today))
        : weekEnd;
    final created = dayOnly(DateTime.parse(habit.created));
    final effectiveStart = created.isAfter(start) ? created : start;
    if (habit.archivedOn != null) {
      final archiveEnd = dayOnly(
        DateTime.parse(habit.archivedOn!),
      ).subtract(const Duration(days: 1));
      if (end.isAfter(archiveEnd)) end = archiveEnd;
    }
    final count = habit.dates
        .where(
          (d) =>
              d.compareTo(dayId(start)) >= 0 &&
              d.compareTo(dayId(weekEnd)) <= 0,
        )
        .length;
    final target = habit.weekly
        ? habit.goal
        : math.max(0, end.difference(effectiveStart).inDays + 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateWeekLabel(dayId(day)), style: ts.textStyle.subtitle),
        SizedBox(height: ts.spacing.sm),
        Text('$status${done ? time : ''}', style: ts.textStyle.content),
        if (before && !done) ...[
          SizedBox(height: ts.spacing.xs),
          Text('创建于 ${habit.created}', style: ts.textStyle.caption),
        ],
        if (!before && !future) ...[
          SizedBox(height: ts.spacing.xs),
          Text(
            '当周完成 $count / $target ${habit.weekly ? '次' : '天'}',
            style: ts.textStyle.caption,
          ),
        ],
      ],
    );
  }
}

/// Borderless opaque habit colors. Completed facts stay primary when archived.
Color habitDayColor(
  TS ts, {
  required bool done,
  required bool inactive,
  required bool archived,
  bool selected = false,
}) {
  final color = done
      ? ts.colors.primary
      : inactive
      ? ts.heatmapOutside
      : archived
      ? ts.heatmapArchived
      : ts.heatmapEmpty;
  return selected
      ? Color.alphaBlend(
          ts.colors.primary.withValues(alpha: ts.opacity.pressed),
          color,
        )
      : color;
}
