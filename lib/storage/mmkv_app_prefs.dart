import 'dart:io';

import 'package:mmkv/mmkv.dart';

import 'app_prefs.dart';

final class MmkvAppPrefs extends AppPrefs {
  MmkvAppPrefs._(this._storage);

  final MMKV _storage;
  bool _closed = false;

  static Future<MmkvAppPrefs> open({
    String id = 'yike',
    String? rootDir,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Use letters, digits, _ or -');
    }
    try {
      final defaultRoot = await MMKV.initialize();
      final directory = rootDir ?? defaultRoot;
      // MMKV's default recovery discards damaged files. Check before opening.
      final dataExists = await File('$directory/$id').exists();
      final metaExists = await File('$directory/$id.crc').exists();
      if (dataExists != metaExists ||
          (dataExists && !MMKV.isFileValid(id, rootDir: directory))) {
        throw const PrefsOpenException(PrefsOpenFailure.damaged);
      }
      return MmkvAppPrefs._(MMKV(id, rootDir: directory));
    } on PrefsOpenException {
      rethrow;
    } catch (error) {
      throw PrefsOpenException(PrefsOpenFailure.unavailable, error);
    }
  }

  @override
  bool containsRaw(PrefsKey key) {
    _ensureOpen();
    return _storage.containsKey(key.storageKey);
  }

  @override
  String? readRaw(PrefsKey key) {
    _ensureOpen();
    return _storage.decodeString(key.storageKey);
  }

  @override
  void writeRaw(PrefsKey key, String value) {
    _ensureOpen();
    if (!_storage.encodeString(key.storageKey, value)) {
      throw StateError('MMKV rejected preference write');
    }
  }

  @override
  void removeRaw(PrefsKey key) {
    _ensureOpen();
    _storage.removeValue(key.storageKey);
  }

  /// MMKV exposes no return status for sync; this is not a disk-failure probe.
  void flush() {
    _ensureOpen();
    _storage.sync(true);
  }

  /// The owner must dispose all users before closing this native instance.
  void close() {
    if (_closed) return;
    _storage.close();
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Preferences are closed');
  }
}
