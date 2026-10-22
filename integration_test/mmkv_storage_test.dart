import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mmkv/mmkv.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/local_data/models/local_data.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'package:yike/storage/app_prefs.dart';
import 'package:yike/storage/mmkv_app_prefs.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native MMKV objects survive close/reopen and deletion', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('yike-mmkv-');
    const id = 'storage_test';
    var prefs = await MmkvAppPrefs.open(id: id, rootDir: root.path);
    try {
      expect(prefs.read(localDataPrefs), isNull);
      final initial = YikeData.initial(DateTime(2026, 10, 22));
      final value = initial.copyWith(
        focus: initial.focus.copyWith(
          preferences: const TimingPreferences(
            focusMinutes: 17,
            shortMinutes: 7,
            longMinutes: 19,
            interval: 3,
            threshold: 15,
            sound: false,
            presets: [90, null, 86399, 1],
          ),
        ),
      );
      prefs.write(localDataPrefs, value);
      prefs.write(AppPrefs.themeMode, 'dark');
      prefs.flush();
      prefs.close();
      expect(() => prefs.read(localDataPrefs), throwsA(isA<PrefsException>()));
      prefs = await MmkvAppPrefs.open(id: id, rootDir: root.path);
      expect(prefs.read(localDataPrefs)!.toJson(), value.toJson());
      expect(prefs.read(AppPrefs.themeMode), 'dark');
      prefs.remove(AppPrefs.themeMode);
      prefs.close();
      prefs = await MmkvAppPrefs.open(id: id, rootDir: root.path);
      expect(prefs.read(AppPrefs.themeMode), isNull);
      expect(prefs.read(localDataPrefs)!.focus.preferences.presets, [
        90,
        null,
        86399,
        1,
      ]);
      prefs.close();
      // Inject malformed business data through the actual native backend.
      final raw = MMKV(id, rootDir: root.path);
      raw.encodeString(PrefsKey.snapshot.storageKey, '{broken');
      raw.close();
      prefs = await MmkvAppPrefs.open(id: id, rootDir: root.path);
      expect(() => prefs.read(localDataPrefs), throwsA(isA<PrefsException>()));
      prefs.close();
      final original = MMKV(id, rootDir: root.path);
      expect(original.decodeString(PrefsKey.snapshot.storageKey), '{broken');
      original.close();
    } finally {
      prefs.close();
      await root.delete(recursive: true);
    }
  });

  testWidgets('damaged native files are rejected without automatic discard', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('yike-mmkv-damage-');
    const id = 'damaged_test';
    final prefs = await MmkvAppPrefs.open(id: id, rootDir: root.path);
    prefs.write(AppPrefs.themePack, 'yike/sundial');
    prefs.flush();
    prefs.close();
    try {
      final file = File('${root.path}/$id');
      final bytes = await file.readAsBytes();
      bytes[8] ^= 0xff;
      await file.writeAsBytes(bytes, flush: true);
      final meta = await File('${root.path}/$id.crc').readAsBytes();
      await expectLater(
        MmkvAppPrefs.open(id: id, rootDir: root.path),
        throwsA(
          isA<PrefsOpenException>().having(
            (e) => e.failure,
            'failure',
            PrefsOpenFailure.damaged,
          ),
        ),
      );
      expect(await file.readAsBytes(), bytes);
      expect(await File('${root.path}/$id.crc').readAsBytes(), meta);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
