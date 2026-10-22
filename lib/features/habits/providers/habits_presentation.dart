import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/time.dart';
import '../models/habit_view.dart';

class HabitsPresentation extends Notifier<List<HabitViewData>> {
  @override
  List<HabitViewData> build() {
    final created = dayId(ref.read(todayProvider));
    return [
      HabitViewData(
        id: 'habit-water',
        name: '喝够 8 杯水',
        icon: HabitIcon.water,
        created: created,
      ),
      HabitViewData(
        id: 'habit-reading',
        name: '读 20 页书',
        icon: HabitIcon.book,
        created: created,
      ),
      HabitViewData(
        id: 'habit-running',
        name: '跑步',
        icon: HabitIcon.running,
        weekly: true,
        created: created,
      ),
      HabitViewData(
        id: 'habit-sleep',
        name: '23 点前睡',
        icon: HabitIcon.moon,
        created: created,
      ),
    ];
  }

  void replace(List<HabitViewData> value) => state = List.unmodifiable(value);
  void save(HabitViewData habit) => state = [
    for (final item in state)
      if (item.id == habit.id) habit else item,
    if (!state.any((item) => item.id == habit.id)) habit,
  ];
  void remove(String id) =>
      state = state.where((item) => item.id != id).toList();
  void toggle(String id, String date) {
    final habit = state
        .where((item) => item.id == id && !item.archived)
        .firstOrNull;
    if (habit == null) return;
    final dates = {...habit.dates};
    dates.contains(date) ? dates.remove(date) : dates.add(date);
    save(habit.copyWith(dates: dates));
  }
}

final habitsProvider =
    NotifierProvider<HabitsPresentation, List<HabitViewData>>(
      HabitsPresentation.new,
    );
