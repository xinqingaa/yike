import 'package:flutter/material.dart' show immutable, StringCharacters;
import '../../../common/time.dart';

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
    this.checkins = const {},
  });
  final String id, name, created;
  final HabitIcon icon;
  final bool weekly, reminder;
  final int goal, reminderMinutes;
  final String? archivedOn;
  final Set<String> dates;
  final Map<String, HabitCheckin> checkins;
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
    Map<String, HabitCheckin>? checkins,
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
    checkins: checkins ?? this.checkins,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon.name,
    'weekly': weekly,
    'goal': goal,
    'reminder': reminder,
    'reminderMinutes': reminderMinutes,
    'created': created,
    'archivedOn': archivedOn,
    'checkins': {for (final e in checkins.entries) e.key: e.value.toJson()},
  };
  factory HabitViewData.fromJson(Map<String, dynamic> j) {
    String date(dynamic value) {
      if (value is! String || dayId(DateTime.parse(value)) != value) {
        throw const FormatException('Invalid habit date');
      }
      return value;
    }

    final id = j['id'] as String,
        name = j['name'] as String,
        goal = j['goal'] as int,
        minutes = j['reminderMinutes'] as int;
    final created = date(j['created']),
        archived = j['archivedOn'] == null ? null : date(j['archivedOn']);
    final checkins = (j['checkins'] as Map<String, dynamic>).map(
      (k, v) =>
          MapEntry(date(k), HabitCheckin.fromJson(v as Map<String, dynamic>)),
    );
    if (id.isEmpty ||
        !validHabitName(name) ||
        name.characters.length > 30 ||
        goal < 1 ||
        goal > 7 ||
        minutes < 0 ||
        minutes >= 1440 ||
        checkins.keys.any((k) => k.compareTo(created) < 0) ||
        checkins.values.map((v) => v.id).toSet().length != checkins.length) {
      throw const FormatException('Invalid habit');
    }
    return HabitViewData(
      id: id,
      name: name,
      icon: HabitIcon.values.byName(j['icon'] as String),
      weekly: j['weekly'] as bool,
      goal: goal,
      reminder: j['reminder'] as bool,
      reminderMinutes: minutes,
      created: created,
      archivedOn: archived,
      dates: Set.unmodifiable(checkins.keys),
      checkins: Map.unmodifiable(checkins),
    );
  }
}

class HabitCheckin {
  const HabitCheckin({required this.id, required this.at});
  final String id;
  final DateTime at;
  Map<String, dynamic> toJson() => {'id': id, 'at': at.toIso8601String()};
  factory HabitCheckin.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    if (id.isEmpty) throw const FormatException('Empty checkin id');
    return HabitCheckin(id: id, at: DateTime.parse(j['at'] as String));
  }
}

String normalizeHabitName(String value) => value
    .trim()
    .replaceAll(RegExp(r'^[\u200B\uFEFF]+|[\u200B\uFEFF]+$'), '')
    .trim();
bool validHabitName(String value) {
  final name = normalizeHabitName(value);
  return name.replaceAll(RegExp(r'[\s\u200B-\u200D\uFEFF]'), '').isNotEmpty &&
      name.characters.length <= 30;
}
