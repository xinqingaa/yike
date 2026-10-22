import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/clock.dart';
import '../../../storage/app_prefs.dart';
import '../../../storage/providers.dart';
import '../../focus/focus_models.dart';
import '../models/local_data.dart';

class LocalDataController extends Notifier<LocalDataState> {
  @override
  LocalDataState build() {
    final prefs = ref.watch(appPrefsProvider), now = ref.read(clockProvider)();
    ref.listen(clockPulseProvider, (_, value) => advance(value));
    try {
      prefs.readString(AppPrefs.themePackKey);
      prefs.readString(AppPrefs.themeModeKey);
      final raw = prefs.readString(AppPrefs.snapshotKey);
      var data = raw == null
          ? YikeData.initial(now)
          : YikeData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final restored = FocusEngine.recover(data.focus);
      final changed = !identical(restored, data.focus);
      data = data.copyWith(focus: restored);
      String? error;
      if (raw == null || changed) {
        try {
          prefs.writeString(AppPrefs.snapshotKey, jsonEncode(data.toJson()));
        } catch (_) {
          error = '尚未保存，关闭后可能丢失，请重试';
        }
      }
      return LocalDataState(data: data, writeError: error);
    } catch (_) {
      return LocalDataState(
        data: YikeData.initial(now),
        readError: '本机数据无法读取或已损坏。原数据已保留，请重试读取或确认重置。',
      );
    }
  }

  bool commit(YikeData data, {bool persist = true, int? completions}) {
    if (state.readError != null) return false;
    if (persist) {
      data = data.copyWith(
        focus: FocusEngine.advance(data.focus, ref.read(clockProvider)()),
      );
    }
    String? error = state.writeError;
    if (persist) {
      try {
        ref
            .read(appPrefsProvider)
            .writeString(AppPrefs.snapshotKey, jsonEncode(data.toJson()));
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
    return error == null;
  }

  bool retry() => commit(state.data);
  void advance(DateTime now) {
    if (state.readError != null) return;
    final previous = state.data.focus,
        next = FocusEngine.advance(previous, now);
    if (identical(previous, next)) return;
    final completed =
        previous.session?.status != TimerStatus.finished &&
        next.session?.status == TimerStatus.finished;
    commit(
      state.data.copyWith(focus: next),
      persist: completed,
      completions: state.completions + (completed ? 1 : 0),
    );
  }

  bool reset() {
    final data = YikeData.initial(ref.read(clockProvider)());
    state = LocalDataState(data: data, revision: state.revision + 1);
    return commit(data);
  }
}

final localDataProvider = NotifierProvider<LocalDataController, LocalDataState>(
  LocalDataController.new,
  dependencies: [appPrefsProvider],
);
