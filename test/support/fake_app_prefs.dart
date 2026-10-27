import 'package:yike/storage/app_prefs.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';

/// Test double only; application builds always use MMKV.
final class FakeAppPrefs extends AppPrefs {
  FakeAppPrefs([Map<String, Object> values = const {}])
    : _values = Map.of(values);

  final Map<String, Object> _values;

  @override
  bool containsRaw(PrefsKey key) => _values.containsKey(key.storageKey);

  @override
  String? readRaw(PrefsKey key) => _values[key.storageKey] as String?;

  @override
  void writeRaw(PrefsKey key, String value) => _values[key.storageKey] = value;

  @override
  void removeRaw(PrefsKey key) => _values.remove(key.storageKey);
}

/// Existing installation for tests unrelated to first-run behavior.
FakeAppPrefs returningAppPrefs() => FakeAppPrefs()
  ..write(
    localDataPrefs,
    YikeData.initial(DateTime(2026, 10, 16)).copyWith(onboardingComplete: true),
  );
