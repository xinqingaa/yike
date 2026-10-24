import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../local_data/local_data.dart';
import '../focus_models.dart';
import 'focus_presentation.dart';

class FocusDialPresentation {
  const FocusDialPresentation(this.session, this.view);
  final FocusSession? session;
  final FocusViewData view;

  /// Sub-second elapsed and anchor stay on the session for the dial ticker.
  /// Listeners rebuild when the visible second, status, laps, or identity change.
  @override
  bool operator ==(Object other) =>
      other is FocusDialPresentation &&
      session?.id == other.session?.id &&
      view == other.view;

  @override
  int get hashCode => Object.hash(session?.id, view);
}

final focusDialPresentationProvider =
    Provider.family<FocusDialPresentation, TimerMode>((ref, mode) {
      final data = ref.watch(focusDataProvider);
      final session = data.session?.mode == mode ? data.session : null;
      final view = data.view.mode == mode
          ? data.view
          : data.copyWith(mode: mode, clearSession: true).view;
      return FocusDialPresentation(session, view);
    }, dependencies: [focusDataProvider]);

class FocusCompletion {
  const FocusCompletion(this.sessionId, this.stage, this.mode);
  final String sessionId;
  final TimerStage stage;
  final TimerMode mode;
}

// Delivery is synchronous and not replayed. Visibility is checked by the
// consumer at the commit, before a later frame can coalesce hide/return.
final focusCompletionEventsProvider = Provider<Stream<FocusCompletion>>((ref) {
  final events = StreamController<FocusCompletion>.broadcast(sync: true);
  ref.listen(localDataProvider, (before, after) {
    final previous = before?.data.focus.session,
        next = after.data.focus.session;
    if (previous != null &&
        next != null &&
        previous.id == next.id &&
        previous.stage == next.stage &&
        previous.status != TimerStatus.finished &&
        next.status == TimerStatus.finished) {
      events.add(FocusCompletion(next.id, next.stage, next.mode));
    }
  });
  ref.onDispose(() => unawaited(events.close()));
  return events.stream;
}, dependencies: [localDataProvider]);
