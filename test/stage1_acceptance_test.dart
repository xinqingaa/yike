// Temporary stage 1 acceptance script. Remove after user acceptance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/app/app.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/feedback/feedback_cue.dart';
import 'package:yike/common/feedback/feedback_service.dart';
import 'package:yike/common/feedback/feedback_options.dart';
import 'package:yike/common/time.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/focus_models.dart';
import 'package:yike/features/focus/logic/focus_beats.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/router/router.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/theme/ts.dart';
import 'features/local_data/local_data_test.dart' show FaultPrefs;
import 'support/pump_presentation.dart';
import 'support/stage1_feedback.dart';

Map<String, FeedbackOptions> testScopes({bool tick = true}) => {
  for (final mode in TimerMode.values)
    mode.name: FeedbackOptions(
      secondTick: mode == TimerMode.countdown && tick,
      beatMinutes: mode == TimerMode.countdown ? 0 : 5,
    ),
  'habits': const FeedbackOptions(beatMinutes: 0),
};
FeedbackService serviceFor(
  RecordingSoundPlayer sound,
  RecordingHapticPlayer haptic,
) =>
    FeedbackService(soundPlayer: sound, hapticPlayer: haptic)
      ..configure(sound: true, haptics: true, scopes: testScopes());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy settings migrate without changing effective modes; new groups round-trip and reject corrupt values',
    () {
      final old = preferencesJson(const TimingPreferences())
        ..remove('feedback');
      old['sound'] = false;
      old['haptics'] = false;
      old['secondTick'] = false;
      old['beatMinutes'] = 10;
      final value = preferencesFromJson(old);
      expect((value.sound, value.haptics), (false, false));
      for (final mode in TimerMode.values) {
        expect(
          (
            value.feedbackFor(mode).sound,
            value.feedbackFor(mode).haptics,
            value.feedbackFor(mode).secondTick,
          ),
          (false, false, false),
        );
      }
      expect(value.pomodoroFeedback.beatMinutes, 10);
      expect(value.stopwatchFeedback.beatMinutes, 10);
      expect(value.countdownFeedback.beatMinutes, 0);
      final changed = value
          .withFeedback(
            TimerMode.stopwatch,
            const FeedbackOptions(secondTick: true, beatMinutes: 1),
          )
          .copyWith(
            habitFeedback: const FeedbackOptions(
              sound: false,
              haptics: true,
              beatMinutes: 0,
            ),
          );
      final restored = preferencesFromJson(preferencesJson(changed));
      expect(restored.stopwatchFeedback.secondTick, isTrue);
      expect(restored.pomodoroFeedback.secondTick, isFalse);
      expect(
        (restored.habitFeedback.sound, restored.habitFeedback.haptics),
        (false, true),
      );
      final ancient = Map<String, dynamic>.of(old)
        ..remove('haptics')
        ..remove('secondTick')
        ..remove('beatMinutes');
      final defaults = preferencesFromJson(ancient);
      expect(defaults.haptics, isTrue);
      expect(defaults.countdownFeedback.secondTick, isTrue);
      expect(defaults.pomodoroFeedback.secondTick, isFalse);
      for (final invalid in [null, 2, 4, -1, 16, '5']) {
        expect(
          () => preferencesFromJson({...old, 'beatMinutes': invalid}),
          throwsA(anything),
        );
        final json = preferencesJson(const TimingPreferences());
        ((json['feedback'] as Map)['pomodoro'] as Map)['beatMinutes'] = invalid;
        expect(() => preferencesFromJson(json), throwsA(anything));
      }
      for (final key in ['haptics', 'secondTick']) {
        expect(
          () => preferencesFromJson({...old, key: null}),
          throwsA(anything),
        );
      }
      expect(
        () => preferencesFromJson({...old, 'feedback': null}),
        throwsA(anything),
      );
      final broken = preferencesJson(const TimingPreferences());
      (broken['feedback'] as Map).remove('habits');
      expect(() => preferencesFromJson(broken), throwsA(anything));
    },
  );

  test('masters and independent preferences persist across reopen', () {
    final disk = FaultPrefs();
    ProviderContainer open() => ProviderContainer(
      overrides: [appPrefsProvider.overrideWithValue(disk)],
    );
    var app = open();
    app
        .read(timingPreferencesProvider.notifier)
        .update(
          (p) => p
              .withFeedback(
                TimerMode.pomodoro,
                const FeedbackOptions(sound: false, beatMinutes: 15),
              )
              .withFeedback(
                TimerMode.stopwatch,
                const FeedbackOptions(secondTick: true, beatMinutes: 1),
              )
              .withFeedback(
                TimerMode.countdown,
                const FeedbackOptions(secondTick: false, beatMinutes: 10),
              )
              .copyWith(
                sound: false,
                haptics: false,
                habitFeedback: const FeedbackOptions(
                  haptics: false,
                  beatMinutes: 0,
                ),
              ),
        );
    app.dispose();
    app = open();
    final p = app.read(timingPreferencesProvider);
    expect((p.sound, p.haptics), (false, false));
    expect(
      (p.pomodoroFeedback.sound, p.pomodoroFeedback.beatMinutes),
      (false, 15),
    );
    expect(
      (p.stopwatchFeedback.secondTick, p.stopwatchFeedback.beatMinutes),
      (true, 1),
    );
    expect(
      (p.countdownFeedback.secondTick, p.countdownFeedback.beatMinutes),
      (false, 10),
    );
    expect(p.habitFeedback.haptics, isFalse);
    app
        .read(timingPreferencesProvider.notifier)
        .update((p) => p.copyWith(sound: true, haptics: true));
    expect(app.read(timingPreferencesProvider).pomodoroFeedback.sound, isFalse);
    expect(app.read(timingPreferencesProvider).habitFeedback.haptics, isFalse);
    app.dispose();
  });

  test('beats use effective boundaries, collapse gaps, skip zero and rest', () {
    FeedbackCue? beat(
      TimerMode mode,
      double before,
      double after, {
      int remaining = 12,
      int minutes = 5,
      TimerStage stage = TimerStage.focus,
      bool? tick,
    }) => focusBeat(
      mode: mode,
      stage: stage,
      previousElapsed: before,
      elapsed: after,
      remainingSeconds: remaining,
      beatMinutes: minutes,
      secondTick: tick ?? mode == TimerMode.countdown,
    );
    for (final mode in TimerMode.values) {
      expect(
        beat(mode, 59.9, 60, minutes: 1, tick: true),
        FeedbackCue.interval,
      );
      expect(beat(mode, 60, 61, minutes: 1, tick: true), FeedbackCue.tick);
      expect(beat(mode, 59, 65, minutes: 1, tick: true), FeedbackCue.tick);
      expect(beat(mode, 60, 61, minutes: 0, tick: false), isNull);
    }
    expect(
      beat(TimerMode.countdown, 59, 65, minutes: 1, tick: false, remaining: 5),
      FeedbackCue.lastSecondsTick,
    );
    expect(beat(TimerMode.countdown, 0, .9), isNull);
    expect(beat(TimerMode.countdown, .9, 1), FeedbackCue.tick);
    expect(beat(TimerMode.countdown, 1, 1), isNull);
    expect(
      beat(TimerMode.countdown, 1, 8, remaining: 10),
      FeedbackCue.lastSecondsTick,
    );
    expect(beat(TimerMode.countdown, 8, 9, remaining: 0), isNull);
    expect(beat(TimerMode.stopwatch, 0, 0), isNull);
    expect(beat(TimerMode.pomodoro, 299.9, 300), FeedbackCue.interval);
    expect(beat(TimerMode.stopwatch, 299, 1000), FeedbackCue.interval);
    expect(beat(TimerMode.stopwatch, 300, 301), isNull);
    expect(
      beat(TimerMode.pomodoro, 299, 300, stage: TimerStage.shortBreak),
      isNull,
    );
    expect(beat(TimerMode.stopwatch, 59, 60, minutes: 0), isNull);
    for (final minutes in [1, 5, 10, 15]) {
      expect(
        beat(
          TimerMode.stopwatch,
          minutes * 60 - .1,
          minutes * 60.0,
          minutes: minutes,
        ),
        FeedbackCue.interval,
      );
    }
  });

  testWidgets(
    'independent channels, disabled tick preserves last-seconds haptic; double impact cancellation',
    (tester) async {
      final sound = RecordingSoundPlayer(), haptic = RecordingHapticPlayer();
      final service = serviceFor(sound, haptic)..setForeground(true);
      service.configure(
        sound: false,
        haptics: true,
        scopes: testScopes(tick: false),
      );
      service.play(
        FeedbackCue.lastSecondsTick,
        theme: 'yike/water',
        scope: 'countdown',
      );
      expect(sound.plays, isEmpty);
      expect(haptic.plays, [HapticCue.light]);
      service.configure(sound: true, haptics: false, scopes: testScopes());
      for (final theme in ['mechanical', 'water', 'sundial']) {
        service.play(
          FeedbackCue.chime,
          theme: 'yike/$theme',
          scope: 'countdown',
        );
      }
      expect(sound.plays.map((e) => e.$1), [
        'yike/mechanical',
        'yike/water',
        'yike/sundial',
      ]);
      expect(haptic.plays, hasLength(1));
      service.configure(sound: true, haptics: true, scopes: testScopes());
      service.play(
        FeedbackCue.interval,
        theme: 'yike/water',
        scope: 'countdown',
      );
      expect(haptic.plays.last, HapticCue.light);
      service.play(FeedbackCue.finish, theme: 'yike/water', scope: 'countdown');
      await tester.pump(const Duration(milliseconds: 119));
      expect(haptic.plays.where((e) => e == HapticCue.heavy), hasLength(1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(haptic.plays.where((e) => e == HapticCue.heavy), hasLength(2));
      service.play(FeedbackCue.finish, theme: 'yike/water', scope: 'countdown');
      service.configure(sound: false, haptics: false, scopes: testScopes());
      await tester.pump(const Duration(milliseconds: 150));
      expect(haptic.plays.where((e) => e == HapticCue.heavy), hasLength(3));
      service.setForeground(false);
      final count = sound.plays.length;
      service.play(
        FeedbackCue.preview,
        theme: 'yike/water',
        scope: 'countdown',
      );
      expect(sound.plays, hasLength(count));
      await service.dispose();
    },
  );

  testWidgets(
    'source switches and masters gate independently; disabling a source cancels its pending impact',
    (tester) async {
      final sound = RecordingSoundPlayer(), haptic = RecordingHapticPlayer();
      final service = serviceFor(sound, haptic)..setForeground(true);
      var scopes = testScopes();
      scopes['stopwatch'] = const FeedbackOptions(sound: false, haptics: false);
      service.configure(sound: true, haptics: true, scopes: scopes);
      service.play(
        FeedbackCue.interval,
        theme: 'yike/water',
        scope: 'stopwatch',
      );
      expect(sound.plays, isEmpty);
      expect(haptic.plays, isEmpty);
      service.play(FeedbackCue.chime, theme: 'yike/water', scope: 'habits');
      expect(haptic.plays.last, HapticCue.medium);
      service.play(FeedbackCue.finish, theme: 'yike/water', scope: 'countdown');
      expect(haptic.plays.last, HapticCue.heavy);
      scopes['countdown'] = scopes['countdown']!.copyWith(
        haptics: false,
        sound: false,
      );
      service.configure(sound: true, haptics: true, scopes: scopes);
      await tester.pump(const Duration(milliseconds: 150));
      expect(haptic.plays.where((e) => e == HapticCue.heavy), hasLength(1));
      final count = sound.plays.length;
      service.configure(sound: false, haptics: false, scopes: scopes);
      service.play(FeedbackCue.chime, theme: 'yike/water', scope: 'habits');
      expect(sound.plays, hasLength(count));
      service.configure(sound: true, haptics: true, scopes: scopes);
      service.play(FeedbackCue.chime, theme: 'yike/water', scope: 'habits');
      expect(sound.plays, hasLength(count + 1));
      service.play(
        FeedbackCue.interval,
        theme: 'yike/water',
        scope: 'stopwatch',
      );
      expect(sound.plays, hasLength(count + 1));
      await service.dispose();
    },
  );

  testWidgets(
    'accepted unsaved commands feedback once; duplicate laps, retries and rejection stay silent',
    (tester) async {
      final disk = FaultPrefs();
      final sound = RecordingSoundPlayer()..fail = true,
          haptic = RecordingHapticPlayer();
      final service = serviceFor(sound, haptic)..setForeground(true);
      var now = DateTime(2026, 10, 24, 12);
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(disk),
          clockProvider.overrideWithValue(() => now),
          feedbackServiceProvider.overrideWithValue(service),
        ],
      );
      final actions = app.read(focusActionsProvider);
      actions.switchMode(TimerMode.stopwatch);
      disk.failWrite = true;
      actions.start();
      actions.start();
      expect(haptic.plays, [HapticCue.light]);
      now = now.add(const Duration(seconds: 2));
      actions.lap();
      actions.lap();
      expect(haptic.plays, hasLength(2));
      actions.pause();
      actions.pause();
      actions.resume();
      actions.resume();
      expect(haptic.plays, hasLength(4));
      app.read(localDataProvider.notifier).retry();
      expect(haptic.plays, hasLength(4));
      final ticket = app
          .read(habitsProvider.notifier)
          .toggle('habit-water', dayId(now));
      expect(ticket, isNotNull);
      expect(haptic.plays.last, HapticCue.medium);
      app.read(rootTabProvider.notifier).set(1);
      // Navigation invalidates the ticket; a rejected undo cannot produce feedback.
      final count = haptic.plays.length;
      app.read(habitsProvider.notifier).undo(ticket!);
      expect(haptic.plays, hasLength(count));
      app.read(habitsProvider.notifier).toggle('habit-water', dayId(now));
      expect(haptic.plays.last, HapticCue.selection);
      final add = app
          .read(habitsProvider.notifier)
          .toggle('habit-water', dayId(now))!;
      app.read(habitsProvider.notifier).undo(add);
      expect(haptic.plays.last, HapticCue.selection);
      app.read(habitsProvider.notifier).toggle('habit-water', dayId(now));
      final removal = app
          .read(habitsProvider.notifier)
          .toggle('habit-water', dayId(now))!;
      final soundsBeforeUndo = sound.plays.length;
      app.read(habitsProvider.notifier).undo(removal);
      expect(
        app
            .read(habitsProvider)
            .firstWhere((h) => h.id == 'habit-water')
            .checkins
            .containsKey(dayId(now)),
        isTrue,
      );
      expect(haptic.plays.last, HapticCue.selection);
      expect(sound.plays, hasLength(soundsBeforeUndo));
      final beforeDiscard = haptic.plays.length;
      actions.discard();
      expect(haptic.plays, hasLength(beforeDiscard));
      app.dispose();
      await service.dispose();
    },
  );

  testWidgets(
    'app-wide beats, completion and background recovery; settings save and preview',
    (tester) async {
      var now = DateTime(2026, 10, 24, 12);
      final sound = RecordingSoundPlayer(), haptic = RecordingHapticPlayer();
      final service = serviceFor(sound, haptic);
      final disk = FaultPrefs();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(disk),
            clockProvider.overrideWithValue(() => now),
            feedbackServiceProvider.overrideWithValue(service),
          ],
          child: const PbApp(),
        ),
      );
      await pumpPresentation(tester);
      final app = ProviderScope.containerOf(
        tester.element(find.byType(CommonBottomNav)),
      );
      final actions = app.read(focusActionsProvider);
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(haptics: false));
      service.play(
        FeedbackCue.light,
        theme: 'yike/mechanical',
        scope: 'countdown',
      );
      expect(haptic.plays, isEmpty);
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(haptics: true));
      void advance(int seconds) {
        now = now.add(Duration(seconds: seconds));
        app.read(clockPulseProvider.notifier).refresh();
      }

      actions.switchMode(TimerMode.countdown);
      actions.selectCountdown(12);
      actions.start();
      app.read(rootTabProvider.notifier).set(1);
      advance(1);
      expect(sound.plays.last, ('yike/mechanical', SoundCue.tick));
      app.read(themePackProvider.notifier).select('yike/water');
      advance(1);
      expect(sound.plays.last, ('yike/water', SoundCue.tick));
      expect(haptic.plays.last, HapticCue.light);
      actions.pause();
      final paused = sound.plays.length;
      advance(3);
      expect(sound.plays, hasLength(paused));
      actions.resume();
      advance(1);
      expect(sound.plays, hasLength(paused + 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final background = sound.plays.length;
      now = now.add(const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(app.read(focusViewProvider).finished, isTrue);
      expect(sound.plays, hasLength(background));
      actions.discard();
      actions.selectCountdown(1);
      actions.start();
      advance(1);
      expect(sound.plays.last, ('yike/water', SoundCue.finish));
      final completed = sound.plays.length;
      app.read(localDataProvider.notifier).retry();
      await pumpPresentation(tester);
      expect(sound.plays, hasLength(completed));
      appNavigatorKey.currentState!.pushNamed(AppRoutes.settings);
      await pumpPresentation(tester);
      Future<void> tapCell(String key) async {
        final target = find.byKey(ValueKey(key));
        await tester.ensureVisible(target);
        await pumpPresentation(tester);
        await tester.tap(target);
        await pumpPresentation(tester);
      }

      await tapCell('feedback/sound');
      expect(app.read(timingPreferencesProvider).sound, isFalse);
      final tick = tester.widget<CommonListCell>(
        find.byKey(const ValueKey('countdown/secondTick')),
      );
      expect(tick.disabled, isTrue);
      final beforePreview = sound.plays.length;
      await tapCell('feedback/sound');
      expect(sound.plays, hasLength(beforePreview + 1));
      expect(sound.plays.last, ('yike/water', SoundCue.chime));
      await tapCell('stopwatch/secondTick');
      expect(
        app.read(timingPreferencesProvider).stopwatchFeedback.secondTick,
        isTrue,
      );
      expect(
        app.read(timingPreferencesProvider).pomodoroFeedback.secondTick,
        isFalse,
      );
      expect(
        app.read(timingPreferencesProvider).countdownFeedback.secondTick,
        isTrue,
      );
      await tapCell('habits/sound');
      expect(app.read(timingPreferencesProvider).habitFeedback.sound, isFalse);
      expect(
        app.read(timingPreferencesProvider).stopwatchFeedback.sound,
        isTrue,
      );
      await tapCell('countdown/beatMinutes');
      await tester.tap(find.text('15 分钟').last);
      await pumpPresentation(tester);
      final current = app.read(timingPreferencesProvider);
      expect(current.countdownFeedback.beatMinutes, 15);
      expect(current.stopwatchFeedback.beatMinutes, 5);
      expect(current.pomodoroFeedback.beatMinutes, 5);
      expect(current.habitFeedback.sound, isFalse);
      await tester.tap(find.byTooltip('关闭').last);
      await pumpPresentation(tester);
      // Close the popup before disposing the root host.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPresentation(tester);
      await service.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
