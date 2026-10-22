import '../../focus/focus_models.dart';
import '../../habits/habit_models.dart';
import '../../../common/time.dart';

class YikeData {
  const YikeData({
    required this.firstUsed,
    required this.focus,
    required this.habits,
  });
  final String firstUsed;
  final FocusData focus;
  final List<HabitViewData> habits;
  factory YikeData.initial(DateTime now) => YikeData(
    firstUsed: dayId(now),
    focus: const FocusData(),
    habits: [
      HabitViewData(
        id: 'habit-water',
        name: '喝够 8 杯水',
        icon: HabitIcon.water,
        created: dayId(now),
      ),
      HabitViewData(
        id: 'habit-reading',
        name: '读 20 页书',
        icon: HabitIcon.book,
        created: dayId(now),
      ),
      HabitViewData(
        id: 'habit-running',
        name: '跑步',
        icon: HabitIcon.running,
        weekly: true,
        created: dayId(now),
      ),
      HabitViewData(
        id: 'habit-sleep',
        name: '23 点前睡',
        icon: HabitIcon.moon,
        created: dayId(now),
      ),
    ],
  );
  YikeData copyWith({FocusData? focus, List<HabitViewData>? habits}) =>
      YikeData(
        firstUsed: firstUsed,
        focus: focus ?? this.focus,
        habits: habits ?? this.habits,
      );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'firstUsed': firstUsed,
    'focus': focus.toJson(),
    'habits': habits.map((h) => h.toJson()).toList(),
  };
  factory YikeData.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) throw const FormatException('Unsupported snapshot');
    final first = validDay(j['firstUsed']);
    final habits = (j['habits'] as List)
        .map((h) => HabitViewData.fromJson(h as Map<String, dynamic>))
        .toList();
    if (habits.map((h) => h.id).toSet().length != habits.length) {
      throw const FormatException('Duplicate habit');
    }
    return YikeData(
      firstUsed: first,
      focus: FocusData.fromJson(j['focus'] as Map<String, dynamic>),
      habits: List.unmodifiable(habits),
    );
  }
}

class LocalDataState {
  const LocalDataState({
    required this.data,
    this.readError,
    this.writeError,
    this.revision = 0,
    this.completions = 0,
  });
  final YikeData data;
  final String? readError, writeError;
  final int revision, completions;
}
