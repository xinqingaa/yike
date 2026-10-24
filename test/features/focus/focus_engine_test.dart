import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/features/focus/focus_models.dart';

void main() {
  final start = DateTime(2026, 10, 16, 12);
  FocusData running(
    TimerMode mode, {
    int target = 300,
    TimingPreferences prefs = const TimingPreferences(),
  }) => FocusEngine.start(
    FocusData(mode: mode, countdown: target, preferences: prefs),
    start,
    'session-a',
  );

  test(
    'countdown completion caps waiting time, settles once, again uses a new identity',
    () {
      var d = running(TimerMode.countdown, target: 5);
      d = FocusEngine.advance(d, start.add(const Duration(seconds: 25)));
      expect(d.session!.status, TimerStatus.finished);
      expect(d.session!.elapsedMs, 5000);
      expect(d.records.single.elapsedMs, 5000);
      expect(FocusEngine.needsConfirmation(d), isFalse);
      d = FocusEngine.advance(d, start.add(const Duration(hours: 1)));
      d = FocusEngine.record(d);
      expect(d.records, hasLength(1));
      d = FocusEngine.start(
        FocusEngine.leave(d),
        start.add(const Duration(hours: 1)),
        'session-b',
      );
      d = FocusEngine.advance(
        d,
        start.add(const Duration(hours: 1, seconds: 5)),
      );
      expect(d.records.map((r) => r.sessionId), ['session-a', 'session-b']);
      expect(d.records.fold<int>(0, (a, r) => a + r.elapsedMs), 10000);
      d = FocusEngine.start(
        FocusEngine.leave(d),
        start.add(const Duration(hours: 2)),
        'session-c',
      );
      expect(FocusEngine.leave(d).records, hasLength(2));
    },
  );
  test('stopwatch laps exclude pauses and produce one total record', () {
    var d = running(TimerMode.stopwatch);
    expect(FocusEngine.lap(d, start).session!.laps, isEmpty);
    d = FocusEngine.lap(d, start.add(const Duration(minutes: 2)));
    d = FocusEngine.lap(d, start.add(const Duration(minutes: 2)));
    expect(d.session!.laps, [120000]);
    d = FocusEngine.pause(d, start.add(const Duration(minutes: 2)));
    d = FocusEngine.advance(d, start.add(const Duration(minutes: 22)));
    expect(d.session!.elapsedMs, 120000);
    d = FocusEngine.resume(d, start.add(const Duration(minutes: 22)));
    d = FocusEngine.finish(d, start.add(const Duration(minutes: 25)));
    expect(d.records.single.elapsedMs, 300000);
    expect(d.session, isNull);
  });
  test(
    'cross midnight preserves exact allocations and one session identity',
    () {
      final from = DateTime(2026, 10, 16, 23, 59, 30);
      var d = FocusEngine.start(
        const FocusData(mode: TimerMode.stopwatch),
        from,
        'cross-day',
      );
      d = FocusEngine.finish(d, from.add(const Duration(seconds: 90)));
      expect(d.records.single.days, {'2026-10-16': 30000, '2026-10-17': 60000});
      expect(d.dailyRecords.map((r) => r.sessionId).toSet(), {'cross-day'});
      expect(d.dailyRecords.fold<num>(0, (a, r) => a + r.seconds), 90);
    },
  );
  test('fractional seconds are retained across midnight', () {
    final from = DateTime(2026, 10, 16, 23, 59, 59, 750);
    var d = FocusEngine.start(
      const FocusData(mode: TimerMode.stopwatch),
      from,
      'fractional',
    );
    d = FocusEngine.finish(
      d,
      from.add(const Duration(milliseconds: 1500)),
      acceptShort: true,
    );
    expect(d.records.single.days, {'2026-10-16': 250, '2026-10-17': 1250});
    expect(d.dailyRecords.fold<num>(0, (a, r) => a + r.seconds), 1.5);
    expect(
      FocusData.fromJson(
        jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
      ).records.single.days,
      d.records.single.days,
    );
  });
  test('cold restore freezes saved progress and retains identity and laps', () {
    var d = running(TimerMode.stopwatch);
    d = FocusEngine.lap(d, start.add(const Duration(seconds: 20)));
    d = FocusEngine.advance(d, start.add(const Duration(seconds: 25)));
    d = FocusEngine.recover(
      FocusData.fromJson(
        jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
      ),
    );
    expect(d.session!.id, 'session-a');
    expect(d.session!.elapsedMs, 25000);
    expect(d.session!.laps, [20000]);
    expect(d.session!.status, TimerStatus.paused);
    expect(d.session!.recovered, isTrue);
    expect(
      FocusEngine.advance(
        d,
        start.add(const Duration(days: 2)),
      ).session!.elapsedMs,
      25000,
    );
  });
  test(
    'four complete rounds choose short short short long then reset cycle',
    () {
      var d = const FocusData(
        preferences: TimingPreferences(
          focusSeconds: 60,
          shortSeconds: 59,
          longSeconds: 120,
        ),
      );
      var now = start;
      for (var round = 1; round <= 4; round++) {
        d = FocusEngine.start(d, now, 'round-$round');
        now = now.add(const Duration(minutes: 1));
        d = FocusEngine.advance(d, now);
        expect(d.cycles, round);
        expect(d.records, hasLength(round));
        d = FocusEngine.record(
          FocusEngine.advance(d, now.add(const Duration(seconds: 30))),
        );
        expect(d.cycles, round);
        d = FocusEngine.beginBreak(d, now, 'rest-$round');
        expect(
          d.session!.stage,
          round == 4 ? TimerStage.longBreak : TimerStage.shortBreak,
        );
        now = now.add(Duration(minutes: round == 4 ? 2 : 1));
        d = FocusEngine.advance(d, now);
        expect(d.records, hasLength(round));
        d = FocusEngine.leave(d);
      }
      expect(d.cycles, 0);
      expect(d.view.round, 1);
    },
  );
  test('round rest decision and running target survive preference changes', () {
    var d = running(
      TimerMode.pomodoro,
      prefs: const TimingPreferences(focusSeconds: 60, interval: 4),
    );
    d = d.copyWith(
      preferences: d.preferences.copyWith(
        focusSeconds: 1800,
        interval: 2,
        shortSeconds: 59,
      ),
    );
    expect(d.session!.targetMs, 60000);
    d = FocusEngine.advance(d, start.add(const Duration(minutes: 1)));
    d = FocusEngine.beginBreak(
      d,
      start.add(const Duration(minutes: 1)),
      'rest',
    );
    expect(d.session!.stage, TimerStage.shortBreak);
    expect(d.session!.targetMs, 59000);
    d = d.copyWith(preferences: d.preferences.copyWith(shortSeconds: 59));
    expect(d.session!.targetMs, 59000);
  });
  test(
    'early end does not complete a round and discard does not erase prior records',
    () {
      var d = running(TimerMode.pomodoro).copyWith(cycles: 2);
      d = FocusEngine.finish(d, start.add(const Duration(seconds: 30)));
      expect(d.cycles, 2);
      expect(d.records.single.elapsedMs, 30000);
      d = FocusEngine.start(
        d,
        start.add(const Duration(minutes: 1)),
        'abandoned',
      );
      d = FocusEngine.leave(d);
      expect(d.cycles, 2);
      expect(d.records, hasLength(1));
    },
  );
  test(
    'short completed pomodoro counts round separately from record acceptance',
    () {
      var d = running(
        TimerMode.pomodoro,
        prefs: const TimingPreferences(focusSeconds: 60, threshold: 180),
      );
      d = FocusEngine.advance(d, start.add(const Duration(minutes: 1)));
      expect(d.cycles, 1);
      expect(d.session!.promptShort, isTrue);
      expect(d.records, isEmpty);
      d = d.copyWith(session: d.session!.copyWith(promptShort: false));
      expect(
        FocusEngine.beginBreak(
          d,
          start.add(const Duration(minutes: 1)),
          'rest',
        ).session!.stage,
        TimerStage.focus,
      );
      final skipped = FocusEngine.leave(d);
      expect(skipped.records, isEmpty);
      expect(skipped.cycles, 1);
      d = FocusEngine.record(d);
      d = FocusEngine.beginBreak(
        d,
        start.add(const Duration(minutes: 1)),
        'rest',
      );
      expect(d.records.single.elapsedMs, 60000);
      expect(d.session!.stage, TimerStage.shortBreak);
    },
  );
  test('short finish freezes progress and cancel stays paused', () {
    var d = running(TimerMode.stopwatch);
    d = FocusEngine.finish(d, start.add(const Duration(milliseconds: 5500)));
    expect(d.session!.status, TimerStatus.paused);
    expect(d.records, isEmpty);
    expect(d.session!.elapsedMs, 5500);
    d = FocusEngine.finish(
      d,
      start.add(const Duration(hours: 1)),
      acceptShort: true,
    );
    expect(d.records.single.elapsedMs, 5500);
  });
  test('zero time creates no record, threshold equality needs no confirm', () {
    expect(
      FocusEngine.finish(running(TimerMode.stopwatch), start).records,
      isEmpty,
    );
    final d = FocusEngine.finish(
      running(TimerMode.stopwatch),
      start.add(const Duration(seconds: 10)),
    );
    expect(d.records.single.elapsedMs, 10000);
  });
  test('already completed record remains idempotent after JSON reload', () {
    var d = FocusEngine.advance(
      running(TimerMode.countdown, target: 1),
      start.add(const Duration(seconds: 1)),
    );
    d = FocusData.fromJson(
      jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
    );
    expect(FocusEngine.record(d).records, hasLength(1));
    expect(
      FocusEngine.advance(d, start.add(const Duration(days: 1))).records,
      hasLength(1),
    );
  });
  test('countdown and stopwatch never reset an in-progress pomodoro cycle', () {
    for (final mode in [TimerMode.countdown, TimerMode.stopwatch]) {
      var d = FocusEngine.start(
        FocusData(mode: mode, cycles: 3, countdown: 1),
        start,
        'other-mode',
      );
      d = FocusEngine.advance(d, start.add(const Duration(seconds: 20)));
      d = FocusEngine.finish(d, start.add(const Duration(seconds: 20)));
      expect(d.cycles, 3);
      expect(d.view.round, 4);
    }
  });
}
