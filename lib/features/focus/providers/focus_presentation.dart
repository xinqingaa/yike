import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/clock.dart';
import '../../../common/identity.dart';
import '../../local_data/local_data.dart';
import '../focus_models.dart';

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
  void set(TimingPreferences value) {
    preferencesFromJson(preferencesJson(value));
    ref.read(focusActionsProvider).configure(value);
  }

  void update(TimingPreferences Function(TimingPreferences) change) =>
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
  void start() => _commit(FocusEngine.start(data, now, identity));
  void pause() => _commit(FocusEngine.pause(data, now));
  void resume() => _commit(FocusEngine.resume(data, now));
  void lap() => _commit(FocusEngine.lap(data, now));
  bool prepareFinish() {
    calibrate();
    if (!FocusEngine.needsConfirmation(data)) return false;
    pause();
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
  void beginBreak() => _commit(FocusEngine.beginBreak(data, now, identity));
  void again() {
    final s = data.session;
    if (s == null ||
        s.mode != TimerMode.countdown ||
        s.status != TimerStatus.finished) {
      return;
    }
    _commit(FocusEngine.start(FocusEngine.leave(data), now, identity));
  }

  void switchMode(TimerMode mode, {bool record = false}) {
    var value = FocusEngine.advance(data, now);
    if (record) {
      if (FocusEngine.needsConfirmation(value)) return;
      value = FocusEngine.finish(value, now);
    } else {
      value = FocusEngine.leave(value);
    }
    _commit(value.copyWith(mode: mode));
  }

  void selectCountdown(int seconds) {
    if (data.session != null || seconds < 1 || seconds > 86399) return;
    _commit(data.copyWith(countdown: seconds));
  }

  void configure(TimingPreferences preferences) {
    _commit(FocusEngine.advance(data, now).copyWith(preferences: preferences));
  }
}

final focusActionsProvider = Provider<FocusActions>(
  FocusActions.new,
  dependencies: [localDataProvider],
);
