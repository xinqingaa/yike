import 'package:yike/storage/app_prefs.dart';

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
