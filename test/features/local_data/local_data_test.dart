import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/time.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/storage/app_prefs.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/storage/preference_writer.dart';
import 'package:yike/theme/ts.dart';
import 'package:flutter/material.dart' show ThemeMode;

class FaultPrefs extends AppPrefs {
  final values = <String, String>{};
  bool failWrite = false, failRead = false;
  int writes = 0;
  @override
  bool containsRaw(PrefsKey key) {
    if (failRead) throw StateError('read failed');
    return values.containsKey(key.storageKey);
  }

  @override
  String? readRaw(PrefsKey key) {
    if (failRead) throw StateError('read failed');
    return values[key.storageKey];
  }

  @override
  void writeRaw(PrefsKey key, String value) {
    if (failWrite) throw StateError('disk full');
    writes++;
    values[key.storageKey] = value;
  }

  @override
  void removeRaw(PrefsKey key) => values.remove(key.storageKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FaultPrefs disk;
  late DateTime now;
  late ProviderContainer app;
  ProviderContainer open() => ProviderContainer(
    overrides: [
      appPrefsProvider.overrideWithValue(disk),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  setUp(() {
    disk = FaultPrefs();
    now = DateTime(2026, 10, 16, 12);
    app = open();
  });
  tearDown(() => app.dispose());
  void advance(Duration duration) {
    now = now.add(duration);
    app.read(clockPulseProvider.notifier).refresh();
  }

  test(
    'countdown always selects a preset and reconciles edits without changing sessions',
    () {
      final actions = app.read(focusActionsProvider);
      final prefs = app.read(timingPreferencesProvider.notifier);
      actions.switchMode(TimerMode.countdown);
      expect(app.read(focusViewProvider).target, 180);
      expect(app.read(focusDataProvider).countdownPreset, 0);
      actions.selectCountdownPreset(300);
      expect(
        actions.adjustDial(
          TimerMode.countdown,
          120,
          expectedValue: 300,
          expectedMaximum: 300,
        ),
        isTrue,
      );
      actions.selectCountdownPreset(300);
      expect(app.read(focusViewProvider).target, 120);
      expect(app.read(focusViewProvider).scaleSeconds, 300);
      prefs.update((p) => p.copyWith(presets: [180, 90, 600, 1200]));
      expect(app.read(focusViewProvider).target, 90);
      expect(app.read(focusDataProvider).countdownPreset, 1);
      actions.start();
      prefs.update((p) => p.copyWith(presets: [30, null, 600, 1200]));
      expect(app.read(focusDataProvider).countdownPreset, 0);
      expect(app.read(focusViewProvider).target, 90);
      expect(app.read(focusViewProvider).scaleSeconds, 90);
      advance(const Duration(seconds: 90));
      actions.again();
      expect(app.read(focusViewProvider).target, 90);
      expect(app.read(focusViewProvider).scaleSeconds, 90);
      actions.discard();
      expect(app.read(focusViewProvider).target, 30);
      expect(app.read(focusViewProvider).scaleSeconds, 30);
    },
  );

  test(
    'first initialization is saved, deleting all habits remains empty after reopen',
    () {
      expect(app.read(habitsProvider), hasLength(4));
      for (final h in [...app.read(habitsProvider)]) {
        app.read(habitsProvider.notifier).remove(h.id);
      }
      app.dispose();
      now = now.add(const Duration(days: 1));
      app = open();
      expect(app.read(habitsProvider), isEmpty);
      expect(app.read(localDataProvider).data.firstUsed, '2026-10-16');
    },
  );
  test(
    'ticks do not save; pause checkpoint cold-restores without closed time',
    () {
      final actions = app.read(focusActionsProvider);
      actions.switchMode(TimerMode.stopwatch);
      actions.start();
      final id = app.read(focusDataProvider).session!.id;
      final count = disk.writes;
      advance(const Duration(seconds: 20));
      expect(disk.writes, count);
      expect(app.read(focusViewProvider).seconds, 20);
      actions.pause();
      actions.resume();
      advance(const Duration(seconds: 10));
      app.dispose();
      now = now.add(const Duration(days: 1));
      app = open();
      expect(app.read(focusViewProvider).seconds, 20);
      expect(app.read(focusDataProvider).session!.id, id);
      expect(app.read(focusViewProvider).paused, isTrue);
      expect(app.read(focusViewProvider).recovered, isTrue);
    },
  );
  test(
    'completion atomically persists result and cannot duplicate after reopen',
    () {
      final a = app.read(focusActionsProvider);
      a.switchMode(TimerMode.countdown);
      a.selectCountdown(1);
      a.start();
      advance(const Duration(seconds: 15));
      expect(app.read(focusRecordsProvider).single.seconds, 1);
      app.dispose();
      app = open();
      expect(app.read(focusViewProvider).finished, isTrue);
      app.read(focusActionsProvider).calibrate();
      expect(app.read(focusRecordsProvider), hasLength(1));
      app.read(focusActionsProvider).again();
      advance(const Duration(seconds: 1));
      expect(app.read(focusRecordsProvider), hasLength(2));
      expect(
        app.read(focusRecordsProvider).map((r) => r.sessionId).toSet(),
        hasLength(2),
      );
    },
  );
  test(
    'mode switch cancellation keeps running, short finish cancellation freezes old mode',
    () {
      final a = app.read(focusActionsProvider);
      a.start();
      advance(const Duration(seconds: 3));
      expect(app.read(focusViewProvider).status, TimerStatus.running);
      expect(a.prepareFinish(), isTrue);
      advance(const Duration(seconds: 20));
      expect(app.read(focusViewProvider).seconds, 1497);
      a.switchMode(TimerMode.countdown, record: true);
      expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
      a.acceptShort();
      a.switchMode(TimerMode.countdown, record: true);
      expect(app.read(focusViewProvider).ready, isTrue);
      expect(app.read(focusViewProvider).mode, TimerMode.countdown);
      expect(app.read(focusRecordsProvider).single.seconds, 3);
    },
  );
  test(
    'habit identities, local checkin identity and archive history survive reopen',
    () {
      final h = app.read(habitsProvider).first;
      final controller = app.read(habitsProvider.notifier);
      controller.toggle(h.id, dayId(now));
      final record = app.read(habitsProvider).first.checkins.values.single;
      controller.save(
        h.copyWith(
          name: '同名也独立',
          reminder: true,
          reminderMinutes: 0,
          archivedOn: dayId(now),
        ),
      );
      app.dispose();
      app = open();
      final restored = app.read(habitsProvider).first;
      expect(restored.id, h.id);
      expect(restored.checkins.values.single.id, record.id);
      expect(restored.reminderMinutes, 0);
      expect(restored.archived, isTrue);
      app.read(habitsProvider.notifier).save(restored.copyWith(restore: true));
      expect(app.read(habitsProvider).first.dates, {dayId(now)});
      expect(app.read(habitsProvider).first.archived, isFalse);
    },
  );
  test(
    'only latest undo is valid and leaving then returning cannot resurrect it',
    () {
      app.read(rootTabProvider.notifier).set(1);
      final h = app.read(habitsProvider.notifier);
      final old = h.toggle('habit-water', dayId(now))!;
      final latest = h.toggle('habit-reading', dayId(now))!;
      expect(h.undo(old), isFalse);
      expect(h.undo(latest), isTrue);
      expect(app.read(habitsProvider).first.dates, {dayId(now)});
      final leave = h.toggle('habit-water', dayId(now))!;
      app.read(rootTabProvider.notifier).set(0);
      app.read(rootTabProvider.notifier).set(1);
      expect(h.undo(leave), isFalse);
      final midnight = h.toggle('habit-water', dayId(now))!;
      advance(const Duration(days: 1));
      expect(h.undo(midnight), isFalse);
      expect(h.toggle('habit-water', '2026-10-16'), isNull);
    },
  );
  test('expired undo and archived or deleted habit cannot change facts', () {
    app.read(rootTabProvider.notifier).set(1);
    final h = app.read(habitsProvider.notifier);
    final expired = h.toggle('habit-water', dayId(now))!;
    advance(const Duration(seconds: 4));
    expect(h.undo(expired), isFalse);
    final ticket = h.toggle('habit-water', dayId(now))!;
    h.save(app.read(habitsProvider).first.copyWith(archivedOn: dayId(now)));
    expect(h.undo(ticket), isFalse);
    expect(h.toggle('habit-water', dayId(now)), isNull);
    final removed = app.read(habitsProvider).first;
    h.remove(removed.id);
    expect(h.save(removed.copyWith(name: '不得复活')), isFalse);
  });
  test('write failure retains a single entity, retry saves same result', () {
    final h = app.read(habitsProvider.notifier),
        created = HabitViewData(id: 'new-one', name: '散步', created: dayId(now));
    disk.failWrite = true;
    expect(h.save(created, create: true), isFalse);
    expect(app.read(localDataProvider).writeError, isNotNull);
    expect(
      app.read(habitsProvider).where((h) => h.id == created.id),
      hasLength(1),
    );
    disk.failWrite = false;
    expect(app.read(localDataProvider.notifier).retry(), isTrue);
    expect(h.save(created, create: true), isTrue);
    app.dispose();
    app = open();
    expect(
      app.read(habitsProvider).where((h) => h.id == created.id),
      hasLength(1),
    );
  });
  test(
    'failed completion save retries same record and keeps in-memory result',
    () {
      final a = app.read(focusActionsProvider);
      a.switchMode(TimerMode.countdown);
      a.selectCountdown(1);
      a.start();
      disk.failWrite = true;
      advance(const Duration(seconds: 2));
      expect(app.read(focusRecordsProvider), hasLength(1));
      expect(app.read(localDataProvider).writeError, isNotNull);
      disk.failWrite = false;
      app.read(localDataProvider.notifier).retry();
      app.dispose();
      app = open();
      expect(app.read(focusRecordsProvider), hasLength(1));
      expect(app.read(focusViewProvider).finished, isTrue);
    },
  );
  test(
    'damaged and future-version snapshots are preserved until explicit reset',
    () {
      for (final raw in [
        '{broken',
        jsonEncode({'schemaVersion': 999}),
      ]) {
        app.dispose();
        disk.values[PrefsKey.snapshot.storageKey] = raw;
        app = open();
        expect(app.read(localDataProvider).readError, isNotNull);
        app.read(focusActionsProvider).start();
        expect(app.read(localDataProvider.notifier).retry(), isFalse);
        expect(disk.values[PrefsKey.snapshot.storageKey], raw);
      }
      expect(app.read(localDataProvider.notifier).reset(), isTrue);
      expect(app.read(habitsProvider), hasLength(4));
      expect(app.read(focusRecordsProvider), isEmpty);
    },
  );
  test('invalid snapshot semantics reject rather than repair history', () {
    final wire = YikeData.initial(now).toJson();
    (wire['focus'] as Map<String, dynamic>)['cycles'] = -1;
    disk.values[PrefsKey.snapshot.storageKey] = jsonEncode({
      'schemaVersion': 2,
      'data': wire,
    });
    expect(app.read(localDataProvider).readError, isNotNull);
    expect(
      jsonDecode(
        disk.values[PrefsKey.snapshot.storageKey]!,
      )['data']['focus']['cycles'],
      -1,
    );
  });
  test('read exception never writes defaults over old storage', () {
    disk.values[PrefsKey.snapshot.storageKey] = 'keep me';
    disk.failRead = true;
    expect(app.read(localDataProvider).readError, isNotNull);
    expect(disk.writes, 0);
    expect(disk.values[PrefsKey.snapshot.storageKey], 'keep me');
  });
  test('configuration round trips exact seconds, empty slots, and sound', () {
    app
        .read(timingPreferencesProvider.notifier)
        .update(
          (p) => p.copyWith(
            presets: [90, null, 3599, 1],
            threshold: 7,
            sound: false,
            focusSeconds: 60,
            interval: 3,
          ),
        );
    app.dispose();
    app = open();
    final p = app.read(timingPreferencesProvider);
    expect(p.presets, [90, null, 3599, 1]);
    expect(p.threshold, 7);
    expect(p.sound, isFalse);
    expect(app.read(focusViewProvider).seconds, 60);
    app.read(focusActionsProvider).switchMode(TimerMode.countdown);
    expect(app.read(focusViewProvider).seconds, 90);
  });
  test(
    'configuration save failure retries the same values and preserves disk',
    () {
      final old = app.read(timingPreferencesProvider);
      disk.failWrite = true;
      final saved = app
          .read(timingPreferencesProvider.notifier)
          .update(
            (p) => p.copyWith(threshold: 15, presets: [90, null, 1, 3599]),
          );
      expect(saved, isFalse);
      expect(app.read(localDataProvider).writeError, isNotNull);
      expect(app.read(timingPreferencesProvider).threshold, 15);
      final previousApp = open();
      expect(
        previousApp.read(timingPreferencesProvider).threshold,
        old.threshold,
      );
      previousApp.dispose();
      disk.failWrite = false;
      expect(app.read(localDataProvider.notifier).retry(), isTrue);
      app.dispose();
      app = open();
      expect(app.read(timingPreferencesProvider).threshold, 15);
      expect(app.read(timingPreferencesProvider).presets, [90, null, 1, 3599]);
    },
  );
  test(
    'new focus duration applies to future sessions and survives cold restore',
    () {
      final actions = app.read(focusActionsProvider);
      actions.start();
      final session = app.read(focusDataProvider).session!;
      expect(
        app
            .read(timingPreferencesProvider.notifier)
            .update((p) => p.copyWith(focusSeconds: 1020, interval: 2)),
        isTrue,
      );
      expect(app.read(focusDataProvider).session!.targetMs, session.targetMs);
      expect(app.read(focusDataProvider).session!.longRest, session.longRest);
      app.dispose();
      app = open();
      expect(app.read(focusViewProvider).paused, isTrue);
      expect(app.read(focusViewProvider).target, 1500);
      expect(app.read(timingPreferencesProvider).focusSeconds, 1020);
      app.read(focusActionsProvider).discard();
      app.read(focusActionsProvider).start();
      expect(app.read(focusViewProvider).target, 17 * 60);
    },
  );
  test(
    'appearance write failure keeps live choice and retry restores it on reopen',
    () {
      app.read(localDataProvider);
      disk.failWrite = true;
      app.read(themePackProvider.notifier).select('yike/sundial');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(app.read(themePackProvider).id, 'yike/sundial');
      expect(app.read(preferenceWriterProvider), hasLength(2));
      disk.failWrite = false;
      expect(app.read(preferenceWriterProvider.notifier).retry(), isTrue);
      app.dispose();
      app = open();
      expect(app.read(themePackProvider).id, 'yike/sundial');
      expect(app.read(themeModeProvider), ThemeMode.dark);
    },
  );
  test(
    'reset write failure retains defaults in memory and preserves old disk until retry',
    () {
      final a = app.read(focusActionsProvider);
      a.switchMode(TimerMode.countdown);
      a.selectCountdown(1);
      a.start();
      advance(const Duration(seconds: 1));
      final old = disk.values[PrefsKey.snapshot.storageKey];
      disk.failWrite = true;
      expect(app.read(localDataProvider.notifier).reset(), isFalse);
      expect(app.read(focusRecordsProvider), isEmpty);
      expect(app.read(habitsProvider), hasLength(4));
      expect(disk.values[PrefsKey.snapshot.storageKey], old);
      disk.failWrite = false;
      app.read(localDataProvider.notifier).retry();
      app.dispose();
      app = open();
      expect(app.read(focusRecordsProvider), isEmpty);
      expect(app.read(focusViewProvider).seconds, 1500);
    },
  );
}
