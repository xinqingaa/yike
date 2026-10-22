import 'package:mmkv/mmkv.dart';

import 'app_prefs.dart';

final class MmkvAppPrefs extends AppPrefs {
  MmkvAppPrefs(this._storage);

  final MMKV _storage;

  static Future<MmkvAppPrefs> open() async {
    await MMKV.initialize();
    return MmkvAppPrefs(MMKV('pb_preferences'));
  }

  @override
  String? readString(String key) => _storage.decodeString(key);

  @override
  void writeString(String key, String value) {
    if (!_storage.encodeString(key, value)) {
      throw StateError('MMKV could not write preference: $key');
    }
  }

  @override
  void remove(String key) => _storage.removeValue(key);
}
