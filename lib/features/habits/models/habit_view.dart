import 'package:flutter/foundation.dart';

enum HabitIcon { leaf, book, water, running, moon, stretch }

@immutable
class HabitViewData {
  const HabitViewData({
    required this.id,
    required this.name,
    this.icon = HabitIcon.leaf,
    this.weekly = false,
    this.goal = 3,
    this.reminder = false,
    this.reminderMinutes = 1260,
    required this.created,
    this.archivedOn,
    this.dates = const {},
  });
  final String id, name, created;
  final HabitIcon icon;
  final bool weekly, reminder;
  final int goal, reminderMinutes;
  final String? archivedOn;
  final Set<String> dates;
  bool get archived => archivedOn != null;
  String get frequency => weekly ? '每周 $goal 次' : '每天';
  HabitViewData copyWith({
    String? name,
    HabitIcon? icon,
    bool? weekly,
    int? goal,
    bool? reminder,
    int? reminderMinutes,
    String? archivedOn,
    bool restore = false,
    Set<String>? dates,
  }) => HabitViewData(
    id: id,
    name: name ?? this.name,
    created: created,
    icon: icon ?? this.icon,
    weekly: weekly ?? this.weekly,
    goal: goal ?? this.goal,
    reminder: reminder ?? this.reminder,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    archivedOn: restore ? null : archivedOn ?? this.archivedOn,
    dates: dates ?? this.dates,
  );
}
