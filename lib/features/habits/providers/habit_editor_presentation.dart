import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show StringCharacters;

import '../../../common/identity.dart';
import '../../../common/time.dart';
import '../models/habit_view.dart';
import 'habits_presentation.dart';

class HabitEditorState {
  const HabitEditorState(this.draft, {this.submitted = false});
  final HabitViewData draft;
  final bool submitted;

  String? get nameError => draft.name.trim().characters.length > 30
      ? '名称最多 30 个字符'
      : submitted && !validHabitName(draft.name)
      ? '写一个习惯名称'
      : null;
}

class HabitEditorController extends Notifier<HabitEditorState> {
  HabitEditorController(this.original);
  final HabitViewData? original;

  @override
  HabitEditorState build() {
    final draft =
        original ??
        HabitViewData(
          id: 'habit-${ref.read(identityProvider)()}',
          name: '',
          created: dayId(ref.read(todayProvider)),
        );
    return HabitEditorState(draft);
  }

  void change(HabitViewData draft) =>
      state = HabitEditorState(draft, submitted: state.submitted);

  bool changeReminderTime(int hours, int minutes) {
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return false;
    change(state.draft.copyWith(reminderMinutes: hours * 60 + minutes));
    return true;
  }

  bool submit() {
    state = HabitEditorState(state.draft, submitted: true);
    if (state.nameError != null) {
      return false;
    }
    return ref
        .read(habitsProvider.notifier)
        .save(
          state.draft.copyWith(name: normalizeHabitName(state.draft.name)),
          create: original == null,
        );
  }
}

NotifierProvider<HabitEditorController, HabitEditorState> habitEditorProvider(
  HabitViewData? original,
) => NotifierProvider.autoDispose<HabitEditorController, HabitEditorState>(
  () => HabitEditorController(original),
  dependencies: [habitsProvider, identityProvider, todayProvider],
);
