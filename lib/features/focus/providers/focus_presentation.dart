import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/clock.dart';
import '../../../common/feedback/feedback_cue.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../theme/ts.dart';
import '../../../common/identity.dart';
import '../../local_data/local_data.dart';
import '../focus_models.dart';
import 'focus_feedback.dart';

final focusDataProvider = Provider<FocusData>(
  (ref) => ref.watch(localDataProvider.select((s) => s.data.focus)),
  dependencies: [localDataProvider],
);
final focusViewProvider = Provider<FocusViewData>(
  (ref) => ref.watch(focusDataProvider).view,
  dependencies: [focusDataProvider],
);
final focusRecordsProvider = Provider<List<FocusRecordView>>(
  (ref) => ref
      .watch(focusDataProvider.select((s) => s.records))
      .expand(
        (r) => [
          for (final d in r.days.entries)
            FocusRecordView(
              date: d.key,
              time:
                  '${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}',
              seconds: d.value / 1000,
              mode: r.mode,
              sessionId: r.sessionId,
            ),
        ],
      )
      .toList(),
  dependencies: [focusDataProvider],
);

class TimingPreferencesController extends Notifier<TimingPreferences> {
  @override
  TimingPreferences build() =>
      ref.watch(focusDataProvider.select((s) => s.preferences));
  bool set(TimingPreferences value) => ref
      .read(focusActionsProvider)
      .configure(preferencesFromJson(preferencesJson(value)));

  bool update(TimingPreferences Function(TimingPreferences) change) =>
      set(change(state));
}

final timingPreferencesProvider =
    NotifierProvider<TimingPreferencesController, TimingPreferences>(
      TimingPreferencesController.new,
      dependencies: [
        focusDataProvider,
        localDataProvider,
        focusActionsProvider,
      ],
    );

/// Commands update the single business snapshot; views only consume projections.
enum FocusCommand {
  pause,
  resume,
  lap,
  record,
  finish,
  discard,
  beginBreak,
  again,
  dismissPrompt,
}

class FocusActions {
  FocusActions(this.ref);
  final Ref ref;
  DateTime get now => ref.read(clockProvider)();
  String get identity => ref.read(identityProvider)();
  FocusData get data => ref.read(localDataProvider).data.focus;
  bool _commit(FocusData value) => ref
      .read(localDataProvider.notifier)
      .commit(ref.read(localDataProvider).data.copyWith(focus: value));
  void calibrate() => ref.read(localDataProvider.notifier).advance(now);
  void _feedbackCommit(FocusData next, {required bool effective}) {
    final result = ref
        .read(localDataProvider.notifier)
        .commitResult(ref.read(localDataProvider).data.copyWith(focus: next));
    if (effective &&
        result.accepted &&
        ref.read(timerFeedbackVisibilityProvider).allows(next.session!.mode)) {
      ref
          .read(feedbackServiceProvider)
          .play(
            FeedbackCue.light,
            theme: ref.read(themePackProvider).id,
            scope: next.session!.mode.name,
          );
    }
  }

  void start() {
    final before = data, next = FocusEngine.start(data, now, identity);
    _feedbackCommit(
      next,
      effective: before.session == null && next.session != null,
    );
  }

  void pause() {
    final before = data, next = FocusEngine.pause(data, now);
    _feedbackCommit(
      next,
      effective:
          before.session?.status == TimerStatus.running &&
          next.session?.status == TimerStatus.paused,
    );
  }

  void resume() {
    final before = data, next = FocusEngine.resume(data, now);
    _feedbackCommit(
      next,
      effective:
          before.session?.status == TimerStatus.paused &&
          next.session?.status == TimerStatus.running,
    );
  }

  void lap() {
    final before = data, next = FocusEngine.lap(data, now);
    _feedbackCommit(
      next,
      effective:
          (next.session?.laps.length ?? 0) > (before.session?.laps.length ?? 0),
    );
  }

  bool prepareFinish() {
    calibrate();
    if (!FocusEngine.needsConfirmation(data)) return false;
    _commit(FocusEngine.pause(data, now));
    return true;
  }

  void acceptShort() => _commit(FocusEngine.record(data));
  void dismissPrompt() {
    final s = data.session;
    if (s != null) {
      _commit(data.copyWith(session: s.copyWith(promptShort: false)));
    }
  }

  bool finish() => _commit(FocusEngine.finish(data, now));
  void discard() => _commit(FocusEngine.leave(FocusEngine.advance(data, now)));
  void beginBreak() {
    final before = data, next = FocusEngine.beginBreak(data, now, identity);
    _feedbackCommit(
      next,
      effective:
          before.session?.id != next.session?.id &&
          next.session?.status == TimerStatus.running,
    );
  }

  void again() {
    final s = data.session;
    if (s == null ||
        s.mode != TimerMode.countdown ||
        s.status != TimerStatus.finished) {
      return;
    }
    _feedbackCommit(FocusEngine.again(data, now, identity), effective: true);
  }

  void switchMode(TimerMode mode) {
    _commit(FocusEngine.advance(data, now).copyWith(mode: mode));
  }

  /// External affordances must carry the identity they actually displayed.
  bool command(
    TimerMode mode,
    String expectedSessionId,
    FocusCommand command,
  ) => commandResult(mode, expectedSessionId, command).accepted;

  CommitResult commandResult(
    TimerMode mode,
    String expectedSessionId,
    FocusCommand command, {
    TimerStage? expectedStage,
    bool feedback = true,
  }) {
    final current = data;
    final session = current.sessionFor(mode);
    if (session?.id != expectedSessionId ||
        (expectedStage != null && session?.stage != expectedStage)) {
      return CommitResult.rejected;
    }
    final requiredStatus = switch (command) {
      FocusCommand.pause || FocusCommand.lap => TimerStatus.running,
      FocusCommand.resume => TimerStatus.paused,
      FocusCommand.again || FocusCommand.beginBreak => TimerStatus.finished,
      _ => null,
    };
    if (requiredStatus != null && session!.status != requiredStatus) {
      return CommitResult.rejected;
    }
    if (command == FocusCommand.record &&
        session!.status == TimerStatus.running) {
      return CommitResult.rejected;
    }
    final selected = current.mode;
    final scoped = current.copyWith(mode: mode);
    final next = switch (command) {
      FocusCommand.pause => FocusEngine.pause(scoped, now),
      FocusCommand.resume => FocusEngine.resume(scoped, now),
      FocusCommand.lap => FocusEngine.lap(scoped, now),
      FocusCommand.record => FocusEngine.record(scoped),
      FocusCommand.finish => FocusEngine.finish(scoped, now),
      FocusCommand.discard => FocusEngine.leave(
        FocusEngine.advance(scoped, now),
      ),
      FocusCommand.beginBreak => FocusEngine.beginBreak(scoped, now, identity),
      FocusCommand.again => FocusEngine.again(scoped, now, identity),
      FocusCommand.dismissPrompt => scoped.copyWith(
        session: scoped.session!.copyWith(promptShort: false),
      ),
    };
    final changed = switch (command) {
      FocusCommand.pause => next.session?.status == TimerStatus.paused,
      FocusCommand.resume => next.session?.status == TimerStatus.running,
      FocusCommand.lap =>
        (next.session?.laps.length ?? 0) > session!.laps.length,
      FocusCommand.beginBreak ||
      FocusCommand.again => next.session?.id != session!.id,
      _ => false,
    };
    final result = ref
        .read(localDataProvider.notifier)
        .commitResult(
          ref
              .read(localDataProvider)
              .data
              .copyWith(focus: next.copyWith(mode: selected)),
        );
    if (feedback &&
        result.accepted &&
        changed &&
        ref.read(timerFeedbackVisibilityProvider).allows(mode)) {
      ref
          .read(feedbackServiceProvider)
          .play(
            FeedbackCue.light,
            theme: ref.read(themePackProvider).id,
            scope: mode.name,
          );
    }
    return result;
  }

  void selectCountdown(int seconds) {
    if (data.session != null ||
        seconds < 1 ||
        seconds > data.countdownMaximum) {
      return;
    }
    _commit(data.copyWith(countdown: seconds));
  }

  void selectCountdownPreset(int seconds) {
    if (data.session != null || data.mode != TimerMode.countdown) return;
    final index = data.preferences.presets.indexOf(seconds);
    if (index < 0) return;
    if (data.countdownPreset == index) return;
    _commit(data.copyWith(countdown: seconds, countdownPreset: index));
  }

  bool adjustDial(
    TimerMode mode,
    int seconds, {
    required int expectedValue,
    required int expectedMaximum,
  }) {
    final current = data;
    if (current.session != null ||
        current.mode != mode ||
        mode == TimerMode.stopwatch) {
      return false;
    }
    final maximum = mode == TimerMode.countdown
        ? current.countdownMaximum
        : maxFocusSeconds;
    final value = mode == TimerMode.countdown
        ? current.countdown
        : current.pomodoroOnce ?? current.preferences.focusSeconds;
    if (value != expectedValue ||
        maximum != expectedMaximum ||
        seconds < 1 ||
        seconds > maximum) {
      return false;
    }
    final next = mode == TimerMode.countdown
        ? current.copyWith(
            countdown: seconds,
            dialAdjusted: current.dialAdjusted || seconds != value,
          )
        : current.copyWith(
            pomodoroOnce: seconds,
            dialAdjusted: current.dialAdjusted || seconds != value,
          );
    final result = ref
        .read(localDataProvider.notifier)
        .commitResult(ref.read(localDataProvider).data.copyWith(focus: next));
    return result.accepted;
  }

  bool configure(TimingPreferences preferences) {
    final before = data;
    return _commit(
      FocusEngine.advance(before, now).copyWith(
        preferences: preferences,
        clearPomodoroOnce:
            preferences.focusSeconds != before.preferences.focusSeconds,
      ),
    );
  }
}

final focusActionsProvider = Provider<FocusActions>(
  FocusActions.new,
  dependencies: [
    localDataProvider,
    feedbackServiceProvider,
    timerFeedbackVisibilityProvider,
    themePackProvider,
  ],
);
