import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/clock.dart';
import '../../../storage/app_prefs.dart';
import '../../../storage/providers.dart';
import '../../focus/focus_models.dart';
import '../models/local_data.dart';
import '../models/local_data_prefs.dart';

class LocalDataController extends Notifier<LocalDataState> {
  @override
  LocalDataState build() {
    final prefs = ref.watch(appPrefsProvider), now = ref.read(clockProvider)();
    ref.listen(clockPulseProvider, (_, value) => advance(value));
    try {
      prefs.read(AppPrefs.themePack);
      prefs.read(AppPrefs.themeMode);
      final stored = prefs.read(localDataPrefs);
      var data = stored ?? YikeData.initial(now);
      final restored = FocusEngine.recover(data.focus);
      final changed = !identical(restored, data.focus);
      data = data.copyWith(focus: restored);
      String? error;
      if (stored == null || changed) {
        try {
          prefs.write(localDataPrefs, data);
        } catch (_) {
          error = '尚未保存，关闭后可能丢失，请重试';
        }
      }
      return LocalDataState(data: data, writeError: error);
    } catch (error) {
      return LocalDataState(
        data: YikeData.initial(now),
        readError:
            error is PrefsException && error.cause is UnsupportedPrefsVersion
            ? '本机数据版本暂不支持。原数据已保留，请更新应用或确认重置。'
            : '本机数据无法读取或已损坏。原数据已保留，请重试读取或确认重置。',
      );
    }
  }

  bool commit(YikeData data, {bool persist = true, int? completions}) {
    final result = commitResult(
      data,
      persist: persist,
      completions: completions,
    );
    return result.accepted && state.writeError == null;
  }

  CommitResult commitResult(
    YikeData data, {
    bool persist = true,
    int? completions,
  }) {
    if (state.readError != null) return CommitResult.rejected;
    if (persist) {
      data = data.copyWith(
        focus: FocusEngine.advance(data.focus, ref.read(clockProvider)()),
      );
    }
    String? error = state.writeError;
    if (persist) {
      try {
        ref.read(appPrefsProvider).write(localDataPrefs, data);
        error = null;
      } catch (_) {
        error = '尚未保存，关闭后可能丢失，请重试';
      }
    }
    state = LocalDataState(
      data: data,
      writeError: error,
      revision: state.revision + 1,
      completions: completions ?? state.completions,
    );
    if (!persist) return CommitResult.inMemory;
    return error == null ? CommitResult.saved : CommitResult.acceptedUnsaved;
  }

  bool retry() => commit(state.data);
  void advance(DateTime now) {
    if (state.readError != null) return;
    final previous = state.data.focus,
        next = FocusEngine.advance(previous, now);
    if (identical(previous, next)) return;
    final completed = TimerMode.values
        .where(
          (mode) =>
              previous.sessionFor(mode)?.status != TimerStatus.finished &&
              next.sessionFor(mode)?.status == TimerStatus.finished,
        )
        .length;
    commit(
      state.data.copyWith(focus: next),
      persist: completed > 0,
      completions: state.completions + completed,
    );
  }

  bool reset() {
    final data = YikeData.initial(
      ref.read(clockProvider)(),
    ).copyWith(onboardingComplete: true);
    state = LocalDataState(data: data, revision: state.revision + 1);
    return commit(data);
  }
}

final localDataProvider = NotifierProvider<LocalDataController, LocalDataState>(
  LocalDataController.new,
  dependencies: [appPrefsProvider],
);
