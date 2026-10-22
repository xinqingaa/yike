import 'dart:convert';

abstract interface class PrefsCodec<T extends Object> {
  T decode(String raw);
  String encode(T value);
}

class StringPrefsCodec implements PrefsCodec<String> {
  const StringPrefsCodec({this.allowedValues});
  final Set<String>? allowedValues;
  @override
  String decode(String raw) {
    if (allowedValues != null && !allowedValues!.contains(raw)) {
      throw const FormatException('Unexpected preference value');
    }
    return raw;
  }

  @override
  String encode(String value) => decode(value);
}

/// Strict JSON primitives, e.g. `JsonPrefsCodec<bool/int/double>`.
class JsonPrefsCodec<T extends Object> implements PrefsCodec<T> {
  const JsonPrefsCodec();
  @override
  T decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! T) throw const FormatException('Unexpected preference type');
    if (value is double && !value.isFinite) {
      throw const FormatException('Nonfinite preference number');
    }
    return value;
  }

  @override
  String encode(T value) => jsonEncode(value);
}

class UnsupportedPrefsVersion implements Exception {
  const UnsupportedPrefsVersion(this.found, this.current);
  final int found, current;
}

/// The model and its validation stay with the caller. No implicit migrations.
class VersionedJsonPrefsCodec<T extends Object> implements PrefsCodec<T> {
  const VersionedJsonPrefsCodec({
    required this.schemaVersion,
    required this.fromJson,
    required this.toJson,
  }) : assert(schemaVersion > 0);

  final int schemaVersion;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  @override
  T decode(String raw) {
    final envelope = jsonDecode(raw);
    if (envelope is! Map<String, dynamic>) {
      throw const FormatException('Expected preference object');
    }
    final version = envelope['schemaVersion'];
    if (version is! int || version < 1) {
      throw const FormatException('Invalid preference version');
    }
    if (version != schemaVersion) {
      throw UnsupportedPrefsVersion(version, schemaVersion);
    }
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected preference payload');
    }
    return fromJson(data);
  }

  @override
  String encode(T value) {
    final raw = jsonEncode({
      'schemaVersion': schemaVersion,
      'data': toJson(value),
    });
    // Validate the actual wire representation before committing it.
    decode(raw);
    return raw;
  }
}
