import 'package:flutter_test/flutter_test.dart';
import 'package:yike/features/focus/focus_models.dart';

void main() {
  final start = DateTime.utc(2026, 10, 26, 12);

  FocusData complete(FocusData data, int round) {
    final begun = FocusEngine.start(data, start, 'focus-$round');
    return FocusEngine.advance(begun, start.add(const Duration(seconds: 20)));
  }

  test('classic loop explains three short rests and one long rest', () {
    const prefs = TimingPreferences();
    expect(prefs.shortSeconds, 300);
    expect(prefs.cycleLength, 4);
    expect(prefs.breakCounts, (short: 3, long: 1));
  });

  test('finite groups end after the last focus without adding a rest', () {
    var data = const FocusData(
      preferences: TimingPreferences(
        focusSeconds: 20,
        shortSeconds: 300,
        longSeconds: 900,
        totalRounds: 5,
        shortInterval: 1,
        interval: 2,
      ),
    );
    expect(data.preferences.breakCounts, (short: 2, long: 2));
    for (var round = 1; round <= 5; round++) {
      data = complete(data, round);
      expect(data.view.round, round);
      expect(data.view.planComplete, round == 5);
      if (round == 5) {
        expect(data.view.breakStage, isNull);
        expect(FocusEngine.beginBreak(data, start, 'invalid'), same(data));
      } else {
        data = FocusEngine.beginBreak(data, start, 'rest-$round');
        expect(
          data.session!.stage,
          round.isEven ? TimerStage.longBreak : TimerStage.shortBreak,
        );
      }
      data = FocusEngine.leave(data);
      expect(data.cycles, round == 5 ? 0 : round);
    }
    expect(data.records, hasLength(5));
    expect(FocusEngine.start(data, start, 'new-group').view.round, 1);
  });

  test('independent frequencies preserve their rhythm across long rests', () {
    var data = const FocusData(
      preferences: TimingPreferences(
        focusSeconds: 20,
        shortInterval: 3,
        interval: 4,
      ),
    );
    expect(data.preferences.cycleLength, 12);
    expect(data.preferences.breakCounts, (short: 3, long: 3));
    for (var round = 1; round <= 12; round++) {
      data = complete(data, round);
      expect(data.view.round, round);
      expect(
        data.view.breakStage,
        round % 4 == 0
            ? TimerStage.longBreak
            : round % 3 == 0
            ? TimerStage.shortBreak
            : null,
      );
      data = FocusEngine.leave(data);
      expect(data.cycles, round == 12 ? 0 : round);
    }
  });

  test(
    'both rest types can be disabled, while finite groups still complete',
    () {
      const prefs = TimingPreferences(
        shortInterval: 0,
        interval: 0,
        totalRounds: 2,
        focusSeconds: 20,
      );
      expect(prefs.breakCounts, (short: 0, long: 0));
      var data = complete(const FocusData(preferences: prefs), 1);
      expect(data.view.breakStage, isNull);
      data = complete(FocusEngine.leave(data), 2);
      expect(data.view.planComplete, isTrue);
      expect(FocusEngine.leave(data).cycles, 0);
    },
  );

  test('running round freezes frequencies, group goal and rest duration', () {
    var data = FocusEngine.start(
      const FocusData(
        preferences: TimingPreferences(
          focusSeconds: 20,
          totalRounds: 5,
          interval: 1,
          longSeconds: 120,
        ),
      ),
      start,
      'running',
    );
    data = data.copyWith(
      preferences: data.preferences.copyWith(
        interval: 0,
        shortInterval: 0,
        totalRounds: 1,
        longSeconds: 900,
      ),
    );
    data = FocusData.fromJson(data.toJson());
    data = data.copyWith(session: data.session!.copyWith(anchor: start));
    data = FocusEngine.advance(data, start.add(const Duration(seconds: 20)));
    expect(data.view.planComplete, isFalse);
    expect(data.view.breakStage, TimerStage.longBreak);
    data = FocusEngine.beginBreak(data, start, 'rest');
    expect(data.session!.targetMs, 120000);
    expect(data.session!.totalRounds, 5);
  });

  test('a shortened plan presents the same next round that start creates', () {
    const data = FocusData(
      cycles: 4,
      preferences: TimingPreferences(totalRounds: 2),
    );
    expect(data.view.round, 1);
    expect(data.view.roundCount, 2);
    final begun = FocusEngine.start(data, start, 'shortened-plan');
    expect(begun.cycles, 0);
    expect(begun.view.round, data.view.round);
  });

  test(
    'configuration persists minute-long short rests and disabled frequencies',
    () {
      const prefs = TimingPreferences(
        shortSeconds: 3599,
        shortInterval: 0,
        interval: 0,
        totalRounds: 99,
      );
      final restored = preferencesFromJson(preferencesJson(prefs));
      expect(restored.shortSeconds, 3599);
      expect(restored.shortInterval, 0);
      expect(restored.interval, 0);
      expect(restored.totalRounds, 99);
      final broken = preferencesJson(prefs)..['totalRounds'] = 100;
      expect(() => preferencesFromJson(broken), throwsFormatException);
    },
  );
}
