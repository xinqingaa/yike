import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/clock.dart';
import '../../../common/feedback/feedback_cue.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../theme/ts.dart';
import '../focus_models.dart';
import '../../local_data/local_data.dart';
import '../logic/focus_projection.dart';
import '../logic/focus_beats.dart';
import 'focus_dial_presentation.dart';

class FocusFeedback {
  FocusFeedback(this.ref);
  final Ref ref;
  double? _elapsed;
  String? _session;
  TimerStage? _stage;

  void reset() {
    _elapsed = null;
    _session = null;
    _stage = null;
  }

  bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return (state == null || state == AppLifecycleState.resumed) &&
        ref.read(feedbackServiceProvider).foreground;
  }

  void sample(DateTime now) {
    final data = ref.read(localDataProvider).data.focus, session = data.session;
    if (!_foreground ||
        session == null ||
        session.status != TimerStatus.running) {
      reset();
      return;
    }
    final projection = FocusProjection.at(session, data.view, now);
    final previous = _session == session.id && _stage == session.stage
        ? _elapsed
        : null;
    _session = session.id;
    _stage = session.stage;
    _elapsed = projection.elapsedSeconds;
    if (previous == null) return;
    final cue = focusBeat(
      mode: session.mode,
      stage: session.stage,
      previousElapsed: previous,
      elapsed: projection.elapsedSeconds,
      remainingSeconds: projection.seconds,
      beatMinutes: data.preferences.feedbackFor(session.mode).beatMinutes,
      secondTick: data.preferences.feedbackFor(session.mode).secondTick,
    );
    if (cue != null) {
      ref
          .read(feedbackServiceProvider)
          .play(
            cue,
            theme: ref.read(themePackProvider).id,
            scope: session.mode.name,
          );
    }
  }

  void completed(FocusCompletion event) {
    reset();
    if (!_foreground) return;
    ref
        .read(feedbackServiceProvider)
        .play(
          FeedbackCue.finish,
          theme: ref.read(themePackProvider).id,
          scope: event.mode.name,
        );
  }
}

/// Kept alive by the application boundary, independently of the selected Tab.
final focusFeedbackProvider = Provider<FocusFeedback>(
  (ref) {
    final feedback = FocusFeedback(ref);
    ref.listen(localDataProvider, (before, after) {
      final previous = before?.data.focus.session,
          next = after.data.focus.session;
      if (previous?.id != next?.id ||
          previous?.stage != next?.stage ||
          previous?.status != next?.status) {
        feedback.reset();
        feedback.sample(ref.read(clockProvider)());
      }
    });
    ref.listen(clockPulseProvider, (_, now) => feedback.sample(now));
    final subscription = ref
        .read(focusCompletionEventsProvider)
        .listen(feedback.completed);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return feedback;
  },
  dependencies: [
    localDataProvider,
    focusCompletionEventsProvider,
    feedbackServiceProvider,
    themePackProvider,
  ],
);
