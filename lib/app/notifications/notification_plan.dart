import '../../common/notifications/notification_models.dart';
import '../../common/notifications/notification_metadata.dart';
import '../../common/time.dart';
import '../../features/focus/focus_models.dart';
import '../../features/local_data/local_data.dart';

/// A bounded desired set from the latest facts. Sorting is global, not per habit.
List<NotificationRequest> notificationPlan(
  YikeData data,
  DateTime now,
  NotificationMetadata metadata,
  String theme,
) {
  if (!data.backgroundReminders) return [];
  final p = data.focus.preferences;
  final result = <NotificationRequest>[];
  for (final mode in TimerMode.values) {
    final s = data.focus.sessionFor(mode);
    if (s == null || s.status != TimerStatus.running || s.anchor == null) {
      continue;
    }
    final at = s.anchor!.add(Duration(milliseconds: s.limitMs - s.elapsedMs));
    if (!at.isAfter(now)) continue;
    final target = NotificationTarget.timer(mode.name, s.id, s.stage.name);
    result.add(
      NotificationRequest(
        id: metadata.idFor(target.key),
        target: target,
        at: at,
        title: s.resting
            ? '休息结束'
            : const ['番茄钟完成', '正计时完成', '倒计时完成'][mode.index],
        body: s.resting
            ? '可以准备下一轮了'
            : mode == TimerMode.stopwatch
            ? '本次计时已达到 59:59'
            : mode == TimerMode.pomodoro
            ? '本轮 ${durationLabel(s.targetMs ~/ 1000)} 已完成'
            : '${durationLabel(s.targetMs ~/ 1000)} 时间到',
        theme: theme,
        sound: p.sound && p.feedbackFor(mode).sound,
        haptics: p.haptics && p.feedbackFor(mode).haptics,
      ),
    );
  }
  final habits = <NotificationRequest>[];
  // 60 future local calendar dates suffice to fill a 60-request budget, even for one habit.
  for (var offset = 0; offset <= 60; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    final date = dayId(day);
    for (final h in data.habits) {
      final target = NotificationTarget.habit(h.id, date);
      if (h.archived ||
          !h.reminder ||
          h.created.compareTo(date) > 0 ||
          h.dates.contains(date) ||
          metadata.consumed.contains(target.key)) {
        continue;
      }
      final at = DateTime(
        day.year,
        day.month,
        day.day,
        h.reminderMinutes ~/ 60,
        h.reminderMinutes % 60,
      );
      if (!at.isAfter(now)) continue;
      habits.add(
        NotificationRequest(
          id: 0,
          target: target,
          at: at,
          title: h.name,
          body: '今日尚未完成',
          theme: theme,
          sound: p.sound && p.habitFeedback.sound,
          haptics: p.haptics && p.habitFeedback.haptics,
        ),
      );
    }
  }
  habits.sort((a, b) {
    final order = a.at.compareTo(b.at);
    return order != 0 ? order : a.target.identity.compareTo(b.target.identity);
  });
  return [
    ...result,
    ...habits.take(60).map((r) => r.withId(metadata.idFor(r.target.key))),
  ];
}
