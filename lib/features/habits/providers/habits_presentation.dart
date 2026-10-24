import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/clock.dart';
import '../../../common/feedback/feedback_cue.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../theme/ts.dart';
import '../../../common/time.dart';
import '../../../common/state/local_value.dart';
import '../../../app/navigation.dart';
import '../../../common/identity.dart';
import '../../local_data/local_data.dart';
import '../models/habit_view.dart';

class HabitUndo {
  const HabitUndo({
    required this.token,
    required this.habitId,
    required this.date,
    required this.previous,
    required this.expires,
    required this.navigationEpoch,
  });
  final String token, habitId, date;
  final HabitCheckin? previous;
  final DateTime expires;
  final int navigationEpoch;
}

enum HabitFeedbackKind { added, removed, restored }

class HabitFeedbackEvent {
  const HabitFeedbackEvent(this.operation, this.habitId, this.kind);
  final String operation, habitId;
  final HabitFeedbackKind kind;
  bool get checked => kind != HabitFeedbackKind.removed;
}

final habitFeedbackProvider =
    NotifierProvider<LocalValue<HabitFeedbackEvent?>, HabitFeedbackEvent?>(
      () => LocalValue(null),
    );

final habitUndoProvider = NotifierProvider<LocalValue<HabitUndo?>, HabitUndo?>(
  () => LocalValue(null),
);

class HabitsPresentation extends Notifier<List<HabitViewData>> {
  @override
  List<HabitViewData> build() {
    ref.listen(rootTabProvider, (before, after) {
      if (before != after) clearUndo();
    });
    ref.listen(todayProvider, (before, after) {
      if (before != after) clearUndo();
    });
    return ref.watch(localDataProvider.select((s) => s.data.habits));
  }

  void clearUndo() => ref.read(habitUndoProvider.notifier).set(null);
  CommitResult replaceResult(List<HabitViewData> value) => ref
      .read(localDataProvider.notifier)
      .commitResult(
        ref
            .read(localDataProvider)
            .data
            .copyWith(habits: List.unmodifiable(value)),
      );
  bool replace(List<HabitViewData> value) => replaceResult(value).persisted;
  bool save(HabitViewData habit, {bool create = false}) {
    final trimmed = normalizeHabitName(habit.name);
    if (!validHabitName(trimmed) ||
        habit.goal < 1 ||
        habit.goal > 7 ||
        habit.reminderMinutes < 0 ||
        habit.reminderMinutes >= 1440) {
      return false;
    }
    final old = state.where((h) => h.id == habit.id).firstOrNull;
    if (old == null && !create) return false;
    if (habit.archived) clearUndo();
    final next = habit.copyWith(
      name: trimmed,
      dates: old?.dates ?? habit.dates,
      checkins: old?.checkins ?? habit.checkins,
    );
    return replace([
      for (final h in state)
        if (h.id == next.id) next else h,
      if (old == null) next,
    ]);
  }

  bool remove(String id) {
    clearUndo();
    return replace(state.where((h) => h.id != id).toList());
  }

  HabitUndo? toggle(
    String id,
    String date, {
    Duration undoDuration = const Duration(seconds: 3),
  }) {
    final now = ref.read(clockProvider)();
    if (date != dayId(ref.read(todayProvider))) return null;
    final habit = state
        .where(
          (h) => h.id == id && !h.archived && h.created.compareTo(date) <= 0,
        )
        .firstOrNull;
    if (habit == null) return null;
    final previous = habit.checkins[date];
    final records = {...habit.checkins};
    if (records.containsKey(date)) {
      records.remove(date);
    } else {
      records[date] = HabitCheckin(id: ref.read(identityProvider)(), at: now);
    }
    final result = replaceResult([
      for (final h in state)
        if (h.id == id)
          h.copyWith(
            dates: Set.unmodifiable(records.keys),
            checkins: Map.unmodifiable(records),
          )
        else
          h,
    ]);
    if (!result.accepted) return null;
    final ticket = HabitUndo(
      token: ref.read(identityProvider)(),
      navigationEpoch: ref.read(rootNavigationEpochProvider),
      habitId: id,
      date: date,
      previous: previous,
      expires: now.add(undoDuration),
    );
    ref.read(habitUndoProvider.notifier).set(ticket);
    ref
        .read(habitFeedbackProvider.notifier)
        .set(
          HabitFeedbackEvent(
            ticket.token,
            id,
            previous == null
                ? HabitFeedbackKind.added
                : HabitFeedbackKind.removed,
          ),
        );
    ref
        .read(feedbackServiceProvider)
        .play(
          previous == null ? FeedbackCue.chime : FeedbackCue.select,
          theme: ref.read(themePackProvider).id,
          scope: 'habits',
        );
    return ticket;
  }

  bool undo(HabitUndo ticket) {
    final active = ref.read(habitUndoProvider);
    final habit = state
        .where((h) => h.id == ticket.habitId && !h.archived)
        .firstOrNull;
    if (active?.token != ticket.token ||
        ticket.navigationEpoch != ref.read(rootNavigationEpochProvider) ||
        habit == null ||
        ref.read(rootTabProvider) != 1 ||
        dayId(ref.read(todayProvider)) != ticket.date ||
        !ref.read(clockProvider)().isBefore(ticket.expires)) {
      return false;
    }
    final records = {...habit.checkins};
    if (ticket.previous == null) {
      records.remove(ticket.date);
    } else {
      records[ticket.date] = ticket.previous!;
    }
    clearUndo();
    final result = replaceResult([
      for (final h in state)
        if (h.id == habit.id)
          h.copyWith(
            dates: Set.unmodifiable(records.keys),
            checkins: Map.unmodifiable(records),
          )
        else
          h,
    ]);
    if (result.accepted) {
      ref
          .read(feedbackServiceProvider)
          .play(
            FeedbackCue.select,
            theme: ref.read(themePackProvider).id,
            scope: 'habits',
          );
      ref
          .read(habitFeedbackProvider.notifier)
          .set(
            HabitFeedbackEvent(
              '${ticket.token}/undo',
              ticket.habitId,
              ticket.previous == null
                  ? HabitFeedbackKind.removed
                  : HabitFeedbackKind.restored,
            ),
          );
    }
    return result.persisted;
  }
}

final habitsProvider =
    NotifierProvider<HabitsPresentation, List<HabitViewData>>(
      HabitsPresentation.new,
      dependencies: [
        localDataProvider,
        habitFeedbackProvider,
        feedbackServiceProvider,
        themePackProvider,
      ],
    );
