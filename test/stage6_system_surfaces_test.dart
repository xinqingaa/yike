import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yike/app/system_surfaces/surface_coordinator.dart';
import 'package:yike/app/system_surfaces/surface_projection.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/system_surfaces/surface_adapter.dart';
import 'package:yike/common/system_surfaces/surface_models.dart';
import 'package:yike/common/system_surfaces/surface_preferences.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/habits/habit_models.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/storage/providers.dart';
import 'support/fake_app_prefs.dart';

class FakeSurfaces implements SystemSurfaceAdapter {
  final published = <SurfaceSnapshot>[];
  final events = <String>[];
  Completer<void>? gate;
  late void Function(String) receive;
  @override
  Future<void> initialize(void Function(String) callback) async {
    receive = callback;
  }

  @override
  Future<SurfaceAccess> access() async => const SurfaceAccess(
    widgets: true,
    activities: true,
    allowed: true,
    shared: true,
  );
  @override
  Future<void> publish(SurfaceSnapshot snapshot) async {
    published.add(snapshot);
    events.add(snapshot.epoch);
    final waiting = gate;
    gate = null;
    if (waiting != null) await waiting.future;
  }

  @override
  Future<void> clear() async {
    events.add('clear');
  }

  @override
  Future<void> openSettings() async {}
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 10, 25, 12);
  SurfaceTimer timer(
    String mode, {
    String status = 'running',
    int elapsed = 0,
    int limit = 5000,
  }) => SurfaceTimer(
    mode: mode,
    session: mode,
    stage: 'focus',
    status: status,
    elapsedMs: elapsed,
    anchorMs: status == 'running'
        ? start.millisecondsSinceEpoch - elapsed
        : null,
    limitMs: limit,
    scaleSeconds: 3600,
    round: 1,
    laps: 0,
  );
  SurfaceSnapshot project(LocalDataState state) => surfaceProjection(
    state,
    start,
    epoch: 'epoch',
    revision: 1,
    ready: true,
    liveEnabled: true,
    theme: 'yike/mechanical',
    appearance: 'system',
  );
  String intent(
    SurfaceSnapshot snapshot,
    SurfaceTimer timer, {
    String? action,
    String? stage,
  }) => Uri(
    scheme: 'yike',
    host: 'surface',
    queryParameters: {
      'v': '1',
      'target': 'focus',
      'action': action ?? (timer.status == 'paused' ? 'resume' : 'pause'),
      'mode': timer.mode,
      'session': timer.session,
      'stage': stage ?? timer.stage,
      'expected': timer.status,
      'epoch': snapshot.epoch,
      'revision': '${snapshot.revision}',
      'token': timer.stateToken,
    },
  ).toString();
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test(
    'priority uses remaining limit, stable ties, paused fallback and caps',
    () {
      final all = [
        timer('countdown'),
        timer('stopwatch', elapsed: 3594000, limit: 3599000),
        timer('pomodoro'),
      ];
      expect(priorityTimer(all, start)?.mode, 'pomodoro');
      expect(priorityTimer(all.take(2).toList(), start)?.mode, 'stopwatch');
      expect(
        priorityTimer([
          timer('stopwatch', elapsed: 3598000, limit: 3599000),
          timer('pomodoro'),
        ], start)?.mode,
        'stopwatch',
      );
      expect(
        priorityTimer([
          timer('countdown', status: 'paused'),
          timer('pomodoro', status: 'paused'),
        ], start)?.mode,
        'pomodoro',
      );
      expect(priorityTimer(all, start.add(const Duration(seconds: 6))), isNull);
      expect(all.first.elapsedAt(start.add(const Duration(hours: 1))), 5000);
    },
  );
  test(
    'habit projection preserves order and full denominator; blocked reads expose no initial facts',
    () {
      final data = YikeData.initial(start).copyWith(
        habits: [
          for (var i = 0; i < 5; i++)
            HabitViewData(
              id: '$i',
              name: '习惯 $i',
              created: '2026-10-25',
              dates: i.isEven ? {'2026-10-25'} : {},
            ),
          const HabitViewData(
            id: 'archived',
            name: '归档',
            created: '2026-10-25',
            archivedOn: '2026-10-25',
          ),
        ],
      );
      final snapshot = project(LocalDataState(data: data));
      expect(snapshot.habitTotal, 5);
      expect(snapshot.habitDone, 3);
      expect(snapshot.habits.map((h) => h['id']), ['0', '1', '2']);
      expect(snapshot.habits.first['done'], true);
      final blocked = project(LocalDataState(data: data, readError: 'blocked'));
      expect(blocked.readable, false);
      expect(blocked.habits, isEmpty);
      expect(blocked.timers, isEmpty);
    },
  );
  test(
    'intent decoder refuses incomplete identities, unrelated links and implicit toggles',
    () {
      final t = timer('pomodoro');
      final s = project(LocalDataState(data: YikeData.initial(start)));
      expect(SurfaceIntent.decode(intent(s, t))?.action, 'pause');
      expect(SurfaceIntent.decode(intent(s, t, action: 'toggle')), isNull);
      expect(SurfaceIntent.decode(intent(s, t, stage: 'other')), isNull);
      expect(
        SurfaceIntent.decode('yike://surface?v=1&target=focus&action=pause'),
        isNull,
      );
      expect(SurfaceIntent.decode('https://surface?v=1&target=focus'), isNull);
      expect(
        SurfaceIntent.decode('yike://surface?v=1&target=habits')?.isCommand,
        false,
      );
    },
  );
  test(
    'pulse calibration does not publish or invalidate the displayed action token',
    () async {
      var now = start;
      final native = FakeSurfaces();
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(FakeAppPrefs()),
          systemSurfaceAdapterProvider.overrideWithValue(native),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(app.dispose);
      app.read(surfaceCoordinatorProvider);
      await flush();
      app.read(focusActionsProvider).start();
      await flush();
      final snapshot = native.published.last,
          row = native.published.last.timers.single;
      final count = native.published.length;
      for (var i = 1; i <= 8; i++) {
        now = start.add(Duration(microseconds: i * 250123));
        app.read(localDataProvider.notifier).advance(now);
      }
      await flush();
      expect(native.published.length, count);
      native.receive(intent(snapshot, row));
      await flush();
      expect(
        app.read(localDataProvider).data.focus.session!.status,
        TimerStatus.paused,
      );
      expect(
        app.read(localDataProvider).data.focus.session!.elapsedMs,
        greaterThan(1900),
      );
    },
  );
  test(
    'duplicate and old-run commands cannot pause a resumed or replaced session',
    () async {
      var now = start;
      final prefs = FakeAppPrefs(), native = FakeSurfaces();
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          systemSurfaceAdapterProvider.overrideWithValue(native),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(app.dispose);
      app.read(surfaceCoordinatorProvider);
      await flush();
      final actions = app.read(focusActionsProvider);
      actions.start();
      await flush();
      final snapshot = native.published.last;
      final raw = intent(snapshot, snapshot.timers.single);
      now = now.add(const Duration(seconds: 2));
      native.receive(raw);
      await flush();
      expect(
        app.read(localDataProvider).data.focus.session!.status,
        TimerStatus.paused,
      );
      final receipts = prefs.read(surfacePreferences)!.consumed;
      expect(receipts, hasLength(1));
      actions.resume();
      await flush();
      native.receive(raw);
      await flush();
      expect(
        app.read(localDataProvider).data.focus.session!.status,
        TimerStatus.running,
      );
      // A still-unused URL from the earlier running phase is also rejected.
      final oldRun = raw.replaceFirst(
        'revision=${snapshot.revision}',
        'revision=${snapshot.revision + 10}',
      );
      native.receive(oldRun);
      await flush();
      expect(
        app.read(localDataProvider).data.focus.session!.status,
        TimerStatus.running,
      );
      expect(prefs.read(surfacePreferences)!.consumed, receipts);
    },
  );
  test(
    'reset is a native barrier and invalidates old commands before new publication',
    () async {
      final native = FakeSurfaces(), prefs = FakeAppPrefs();
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          systemSurfaceAdapterProvider.overrideWithValue(native),
          clockProvider.overrideWithValue(() => start),
        ],
      );
      addTearDown(app.dispose);
      app.read(surfaceCoordinatorProvider);
      await flush();
      final old = native.published.last.epoch;
      final gate = Completer<void>();
      native.gate = gate;
      app.read(focusActionsProvider).start();
      await flush();
      final snapshot = native.published.last;
      final actions = app.read(surfaceCoordinatorProvider.notifier);
      expect(actions.beginReset(), true);
      app.read(localDataProvider.notifier).reset();
      native.receive(intent(snapshot, snapshot.timers.single));
      expect(prefs.read(surfacePreferences)!.epoch, isNot(old));
      expect(native.events, isNot(contains('clear')));
      gate.complete();
      await flush();
      expect(
        native.events.indexOf('clear'),
        greaterThan(native.events.indexOf(old)),
      );
      expect(native.events.last, prefs.read(surfacePreferences)!.epoch);
      expect(native.published.last.timers, isEmpty);
      expect(app.read(localDataProvider).data.focus.allSessions, isEmpty);
    },
  );
}
