import '../../focus/focus_models.dart';
import '../../habits/habit_models.dart';
import '../../../common/time.dart';

class YikeData {
  const YikeData({
    required this.firstUsed,
    required this.focus,
    required this.habits,
    this.backgroundReminders = false,
    this.onboardingComplete = true,
  });
  final bool backgroundReminders;
  final bool onboardingComplete;
  final String firstUsed;
  final FocusData focus;
  final List<HabitViewData> habits;
  factory YikeData.initial(DateTime now) => YikeData(
    onboardingComplete: false,
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
  YikeData copyWith({
    FocusData? focus,
    List<HabitViewData>? habits,
    bool? backgroundReminders,
    bool? onboardingComplete,
  }) => YikeData(
    firstUsed: firstUsed,
    backgroundReminders: backgroundReminders ?? this.backgroundReminders,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    focus: focus ?? this.focus,
    habits: habits ?? this.habits,
  );
  Map<String, dynamic> toJson() => {
    'firstUsed': firstUsed,
    'onboardingComplete': onboardingComplete,
    'backgroundReminders': backgroundReminders,
    'focus': focus.toJson(),
    'habits': habits.map((h) => h.toJson()).toList(),
  };
  factory YikeData.fromJson(Map<String, dynamic> j) {
    final first = validDay(j['firstUsed']);
    final habits = (j['habits'] as List)
        .map((h) => HabitViewData.fromJson(h as Map<String, dynamic>))
        .toList();
    if (habits.map((h) => h.id).toSet().length != habits.length) {
      throw const FormatException('Duplicate habit');
    }
    return YikeData(
      firstUsed: first,
      onboardingComplete: j['onboardingComplete'] as bool? ?? true,
      backgroundReminders: j['backgroundReminders'] as bool,
      focus: FocusData.fromJson(j['focus'] as Map<String, dynamic>),
      habits: List.unmodifiable(habits),
    );
  }
}

enum CommitResult {
  rejected,
  inMemory,
  acceptedUnsaved,
  saved;

  bool get accepted => this != rejected;
  bool get persisted => this == saved;
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
