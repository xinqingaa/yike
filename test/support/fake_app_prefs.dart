import 'package:yike/storage/app_prefs.dart';

/// Test double only; application builds always use MMKV.
final class FakeAppPrefs extends AppPrefs {
  FakeAppPrefs([Map<String, Object> values = const {}])
    : _values = Map.of(values);

  final Map<String, Object> _values;

  @override
  String? readString(String key) => _values[key] as String?;

  @override
  void writeString(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}
