import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/focus/focus_models.dart';

class TimerStatusEntry {
  const TimerStatusEntry(
    this.session, {
    this.completed = false,
    this.exiting = false,
  });
  final FocusSession session;
  final bool completed, exiting;
  TimerStatusEntry copyWith({
    FocusSession? session,
    bool? completed,
    bool? exiting,
  }) => TimerStatusEntry(
    session ?? this.session,
    completed: completed ?? this.completed,
    exiting: exiting ?? this.exiting,
  );
}

class TimerStatusState {
  const TimerStatusState({
    this.entries = const {},
    this.collapsed = false,
    this.dragging = false,
    this.foreground = true,
  });
  final Map<String, TimerStatusEntry> entries;
  final bool collapsed, dragging, foreground;
  TimerStatusState copyWith({
    Map<String, TimerStatusEntry>? entries,
    bool? collapsed,
    bool? dragging,
    bool? foreground,
  }) => TimerStatusState(
    entries: entries == null ? this.entries : Map.unmodifiable(entries),
    collapsed: collapsed ?? this.collapsed,
    dragging: dragging ?? this.dragging,
    foreground: foreground ?? this.foreground,
  );
}

/// Instance-scoped presentation state. Sessions remain owned by local_data.
class TimerStatusController extends Notifier<TimerStatusState> {
  final _timeouts = <String, Timer>{};
  @override
  TimerStatusState build() {
    ref.onDispose(() {
      for (final timer in _timeouts.values) {
        timer.cancel();
      }
    });
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return TimerStatusState(
      foreground: lifecycle == null || lifecycle == AppLifecycleState.resumed,
    );
  }

  void collapse(bool value) =>
      state = state.copyWith(collapsed: value, dragging: false);
  void drag(bool value) => state = state.copyWith(dragging: value);
  void foreground(bool value) =>
      state = state.copyWith(foreground: value, dragging: false);

  void _cancel(String id) => _timeouts.remove(id)?.cancel();

  void complete(FocusSession session) {
    final entry = state.entries[session.id];
    if (entry == null || entry.exiting || entry.completed) return;
    state = state.copyWith(
      entries: {
        ...state.entries,
        session.id: entry.copyWith(session: session, completed: true),
      },
    );
    _cancel(session.id);
    _timeouts[session.id] = Timer(const Duration(milliseconds: 980), () {
      _timeouts.remove(session.id);
      if (!ref.mounted) return;
      final current = state.entries[session.id];
      if (current == null || !current.completed) return;
      state = state.copyWith(
        entries: {
          ...state.entries,
          session.id: current.copyWith(exiting: true),
        },
      );
    });
  }

  void reconcile(
    FocusData data, {
    required bool shown,
    required TimerMode? currentMode,
    required bool folded,
    required Set<String> invalidCompletions,
  }) {
    final entries = {...state.entries};
    for (final entry in state.entries.values) {
      final id = entry.session.id;
      final latest = data.sessionFor(entry.session.mode);
      final eligible = currentMode != entry.session.mode && latest?.id == id;
      if (invalidCompletions.contains(id) ||
          (entry.completed && (!shown || folded))) {
        entries.remove(id);
        _cancel(id);
      } else if (entry.completed) {
        if (!eligible) {
          entries[id] = entry.copyWith(exiting: true);
          _cancel(id);
        }
      } else if (!eligible || latest?.status == TimerStatus.finished) {
        if (!shown || folded) {
          entries.remove(id);
          _cancel(id);
        } else {
          entries[id] = entry.copyWith(exiting: true);
        }
      } else {
        entries[id] = entry.copyWith(session: latest!, exiting: false);
      }
    }
    for (final session in data.allSessions.values) {
      if (session.mode != currentMode &&
          session.status != TimerStatus.finished) {
        entries.putIfAbsent(session.id, () => TimerStatusEntry(session));
      }
    }
    state = state.copyWith(entries: entries);
  }

  void remove(String id) {
    if (state.entries[id]?.exiting != true) return;
    _cancel(id);
    state = state.copyWith(entries: {...state.entries}..remove(id));
  }
}
