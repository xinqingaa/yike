import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yike/features/local_data/models/local_data.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/storage/app_prefs.dart';

import 'support/fake_app_prefs.dart';

class BrokenPrefs extends AppPrefs {
  bool unreadable = false,
      failRead = false,
      failWrite = false,
      failRemove = false;
  final values = <PrefsKey, String>{};
  @override
  bool containsRaw(PrefsKey key) {
    if (failRead) throw StateError('read failed');
    return values.containsKey(key);
  }

  @override
  String? readRaw(PrefsKey key) => unreadable ? null : values[key];
  @override
  void writeRaw(PrefsKey key, String value) {
    if (failWrite) throw StateError('disk full');
    values[key] = value;
  }

  @override
  void removeRaw(PrefsKey key) {
    if (!failRemove) values.remove(key);
  }
}

Matcher failure(PrefsOperation operation, {Matcher? cause}) =>
    isA<PrefsException>()
        .having((e) => e.operation, 'operation', operation)
        .having((e) => e.cause, 'cause', cause ?? anything);

void main() {
  test('absence is distinct from empty strings, false and zero', () {
    final prefs = FakeAppPrefs();
    expect(prefs.read(AppPrefs.themePack), isNull);
    prefs.write(AppPrefs.themePack, '');
    expect(prefs.read(AppPrefs.themePack), '');
    const boolean = PrefsEntry(PrefsKey.snapshot, JsonPrefsCodec<bool>());
    const integer = PrefsEntry(PrefsKey.snapshot, JsonPrefsCodec<int>());
    const decimal = PrefsEntry(PrefsKey.snapshot, JsonPrefsCodec<double>());
    prefs.write(boolean, false);
    expect(prefs.read(boolean), false);
    prefs.write(integer, 0);
    expect(prefs.read(integer), 0);
    prefs.write(decimal, 0.125);
    expect(prefs.read(decimal), 0.125);
  });

  test(
    'invalid types and nonfinite numbers never silently become defaults',
    () {
      const integer = PrefsEntry(PrefsKey.snapshot, JsonPrefsCodec<int>());
      const decimal = PrefsEntry(PrefsKey.snapshot, JsonPrefsCodec<double>());
      final prefs = FakeAppPrefs({'business_snapshot': 'true'});
      expect(() => prefs.read(integer), throwsA(failure(PrefsOperation.read)));
      expect(
        () => prefs.write(decimal, double.nan),
        throwsA(failure(PrefsOperation.write)),
      );
      const boolean = PrefsEntry(PrefsKey.snapshot, JsonPrefsCodec<bool>());
      expect(prefs.read(boolean), true);
      expect(
        () => FakeAppPrefs({'business_snapshot': '1e999'}).read(decimal),
        throwsA(failure(PrefsOperation.read)),
      );
    },
  );

  test('theme modes validate on both reads and writes', () {
    final prefs = FakeAppPrefs();
    for (final mode in ['light', 'dark', 'system']) {
      prefs.write(AppPrefs.themeMode, mode);
      expect(prefs.read(AppPrefs.themeMode), mode);
    }
    expect(
      () => prefs.write(AppPrefs.themeMode, 'unknown'),
      throwsA(failure(PrefsOperation.write, cause: isA<FormatException>())),
    );
    expect(prefs.read(AppPrefs.themeMode), 'system');
    expect(
      () => FakeAppPrefs({'theme_mode': 'unknown'}).read(AppPrefs.themeMode),
      throwsA(failure(PrefsOperation.read, cause: isA<FormatException>())),
    );
  });

  test('versioned business objects round trip seconds, slots and order', () {
    final prefs = FakeAppPrefs();
    final initial = YikeData.initial(DateTime(2026, 10, 22));
    final value = initial.copyWith(
      focus: initial.focus.copyWith(
        preferences: const TimingPreferences(
          presets: [90, null, 86399, 1],
          threshold: 15,
          sound: false,
        ),
      ),
    );
    prefs.write(localDataPrefs, value);
    final restored = prefs.read(localDataPrefs)!;
    expect(restored.toJson(), value.toJson());
    expect(restored.focus.preferences.presets, [90, null, 86399, 1]);
    expect(restored.focus.preferences.threshold, 15);
  });

  test('invalid objects are rejected before replacing the previous value', () {
    final prefs = FakeAppPrefs();
    final initial = YikeData.initial(DateTime(2026, 10, 22));
    prefs.write(localDataPrefs, initial);
    final invalid = initial.copyWith(
      focus: initial.focus.copyWith(
        preferences: const TimingPreferences(presets: [90, 90, null, null]),
      ),
    );
    expect(
      () => prefs.write(localDataPrefs, invalid),
      throwsA(failure(PrefsOperation.write, cause: isA<FormatException>())),
    );
    expect(prefs.read(localDataPrefs)!.toJson(), initial.toJson());
  });

  test('corruption and unknown schemas leave the original bytes untouched', () {
    for (final raw in [
      '{broken',
      'null',
      '[]',
      '{"schemaVersion":"1","data":{}}',
      '{"schemaVersion":1,"data":[]}',
      '{"schemaVersion":999,"data":{}}',
    ]) {
      final prefs = BrokenPrefs()..values[PrefsKey.snapshot] = raw;
      expect(
        () => prefs.read(localDataPrefs),
        throwsA(failure(PrefsOperation.read)),
      );
      expect(prefs.values[PrefsKey.snapshot], raw);
    }
    final prefs = FakeAppPrefs({
      'business_snapshot': jsonEncode({'schemaVersion': 999, 'data': {}}),
    });
    expect(
      () => prefs.read(localDataPrefs),
      throwsA(
        failure(PrefsOperation.read, cause: isA<UnsupportedPrefsVersion>()),
      ),
    );
  });

  test('an existing undecodable native value is not treated as absent', () {
    final prefs = BrokenPrefs()
      ..values[PrefsKey.themePack] = 'keep'
      ..unreadable = true;
    expect(
      () => prefs.read(AppPrefs.themePack),
      throwsA(failure(PrefsOperation.read)),
    );
    expect(prefs.values[PrefsKey.themePack], 'keep');
  });

  test(
    'backend failures retain key, operation and cause without user contents',
    () {
      final prefs = BrokenPrefs()..failRead = true;
      expect(
        () => prefs.read(AppPrefs.themePack),
        throwsA(failure(PrefsOperation.read)),
      );
      prefs.failRead = false;
      prefs.write(AppPrefs.themePack, 'yike/water');
      prefs.failWrite = true;
      expect(
        () => prefs.write(AppPrefs.themePack, 'yike/sundial'),
        throwsA(failure(PrefsOperation.write)),
      );
      expect(prefs.read(AppPrefs.themePack), 'yike/water');
      final error = PrefsException(
        PrefsKey.snapshot,
        PrefsOperation.read,
        const FormatException('private habit title'),
      );
      expect(error.toString(), contains('business_snapshot'));
      expect(error.toString(), isNot(contains('private habit title')));
    },
  );

  test('deletion must be verified and is safe to retry', () {
    final prefs = BrokenPrefs()..values[PrefsKey.themePack] = 'yike/water';
    prefs.failRemove = true;
    expect(
      () => prefs.remove(AppPrefs.themePack),
      throwsA(failure(PrefsOperation.remove)),
    );
    expect(prefs.read(AppPrefs.themePack), 'yike/water');
    prefs.failRemove = false;
    prefs.remove(AppPrefs.themePack);
    prefs.remove(AppPrefs.themePack);
    expect(prefs.read(AppPrefs.themePack), isNull);
  });
}
