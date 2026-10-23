import 'package:flutter/foundation.dart';

import 'prefs_codec.dart';

export 'prefs_codec.dart';

/// Registered on-disk identities. Add keys to docs/engineering/storage.md first.
enum PrefsKey {
  themeMode('theme_mode'),
  themePack('theme_pack'),
  snapshot('business_snapshot');

  const PrefsKey(this.storageKey);
  final String storageKey;
}

/// A registered key bound to its value type and wire format.
class PrefsEntry<T extends Object> {
  const PrefsEntry(this.key, this.codec);
  final PrefsKey key;
  final PrefsCodec<T> codec;
}

enum PrefsOperation { read, write, remove }

enum PrefsOpenFailure { unavailable, damaged }

class PrefsOpenException implements Exception {
  const PrefsOpenException(this.failure, [this.cause]);
  final PrefsOpenFailure failure;
  final Object? cause;
  @override
  String toString() => 'PrefsOpenException(${failure.name})';
}

class PrefsException implements Exception {
  const PrefsException(this.key, this.operation, this.cause);
  final PrefsKey key;
  final PrefsOperation operation;
  final Object cause;

  // Decoder messages may contain user data. Do not include them in diagnostics.
  @override
  String toString() =>
      'PrefsException(${operation.name}, ${key.storageKey}, ${cause.runtimeType})';
}

/// Application storage boundary. MMKV is the sole production backend.
abstract class AppPrefs {
  static const themeMode = PrefsEntry(
    PrefsKey.themeMode,
    StringPrefsCodec(allowedValues: {'light', 'dark', 'system'}),
  );
  static const themePack = PrefsEntry(PrefsKey.themePack, StringPrefsCodec());

  /// Only an absent key returns null. Decode and backend failures throw.
  T? read<T extends Object>(PrefsEntry<T> entry) {
    try {
      if (!containsRaw(entry.key)) return null;
      final raw = readRaw(entry.key);
      if (raw == null) throw const FormatException('Unreadable stored value');
      return entry.codec.decode(raw);
    } catch (error) {
      throw PrefsException(entry.key, PrefsOperation.read, error);
    }
  }

  void write<T extends Object>(PrefsEntry<T> entry, T value) {
    try {
      // Complete serialization and validation before touching existing data.
      final raw = entry.codec.encode(value);
      writeRaw(entry.key, raw);
    } catch (error) {
      throw PrefsException(entry.key, PrefsOperation.write, error);
    }
  }

  void remove<T extends Object>(PrefsEntry<T> entry) {
    try {
      removeRaw(entry.key);
      if (containsRaw(entry.key)) throw StateError('Value was not removed');
    } catch (error) {
      throw PrefsException(entry.key, PrefsOperation.remove, error);
    }
  }

  @protected
  bool containsRaw(PrefsKey key);
  @protected
  String? readRaw(PrefsKey key);
  @protected
  void writeRaw(PrefsKey key, String value);
  @protected
  void removeRaw(PrefsKey key);
}
