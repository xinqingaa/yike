import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show StringCharacters;

import '../../../common/identity.dart';
import '../../../common/time.dart';
import '../models/habit_view.dart';
import 'habits_presentation.dart';

class HabitEditorState {
  const HabitEditorState(this.draft, this.timeText, {this.submitted = false});
  final HabitViewData draft;
  final String timeText;
  final bool submitted;

  String? get nameError => draft.name.trim().characters.length > 30
      ? '名称最多 30 个字符'
      : submitted && !validHabitName(draft.name)
      ? '写一个习惯名称'
      : null;

  int? get reminderMinutes {
    final parts = timeText.split(':');
    final h = parts.length == 2 ? int.tryParse(parts.first) : null;
    final m = parts.length == 2 ? int.tryParse(parts.last) : null;
    return h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59
        ? h * 60 + m
        : null;
  }

  String? get timeError => reminderMinutes == null ? '输入有效时间，例如 21:00' : null;
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
    final minutes = draft.reminderMinutes;
    return HabitEditorState(
      draft,
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
    );
  }

  void change(HabitViewData draft) => state = HabitEditorState(
    draft,
    state.timeText,
    submitted: state.submitted,
  );

  void changeTime(String value) =>
      state = HabitEditorState(state.draft, value, submitted: state.submitted);

  bool submit() {
    state = HabitEditorState(state.draft, state.timeText, submitted: true);
    if (state.nameError != null ||
        (state.draft.reminder && state.timeError != null)) {
      return false;
    }
    return ref
        .read(habitsProvider.notifier)
        .save(
          state.draft.copyWith(
            name: normalizeHabitName(state.draft.name),
            reminderMinutes:
                state.reminderMinutes ?? state.draft.reminderMinutes,
          ),
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
