import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'app_prefs.dart';

/// Failed preference writes remain retryable while the chosen appearance is live.
class PreferenceWriter extends Notifier<Map<PrefsEntry<String>, String>> {
  @override
  Map<PrefsEntry<String>, String> build() => const {};
  bool save(PrefsEntry<String> key, String value) {
    state = {...state, key: value};
    return retry();
  }

  bool retry() {
    final pending = {...state};
    for (final entry in state.entries) {
      try {
        ref.read(appPrefsProvider).write(entry.key, entry.value);
        pending.remove(entry.key);
      } catch (_) {
        break;
      }
    }
    state = Map.unmodifiable(pending);
    return state.isEmpty;
  }
}

final preferenceWriterProvider =
    NotifierProvider<PreferenceWriter, Map<PrefsEntry<String>, String>>(
      PreferenceWriter.new,
      dependencies: [appPrefsProvider],
    );
