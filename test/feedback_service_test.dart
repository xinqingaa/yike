import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yike/app/app.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/notifications/notification_adapter.dart';
import 'package:yike/common/overlay/popup_activity.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/providers/focus_dial_presentation.dart';
import 'package:yike/storage/providers.dart';
import 'support/fake_app_prefs.dart';
import 'package:yike/features/settings/providers/sound_audition.dart';
import 'support/fake_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/feedback/feedback_cue.dart';
import 'package:yike/common/feedback/feedback_service.dart';
import 'package:yike/common/feedback/feedback_options.dart';
import 'package:yike/common/feedback/haptic_player.dart';
import 'package:yike/common/feedback/sound_player.dart';

class _Sounds implements SoundPlayer {
  final calls = <(String, SoundCue)>[];
  final stops = <String?>[];
  @override
  bool get ready => true;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> play(String theme, SoundCue cue, {required String scope}) async {
    calls.add((theme, cue));
  }

  @override
  Future<void> stop({String? scope}) async {
    stops.add(scope);
  }

  @override
  Future<void> dispose() async {}
}

class _Haptics implements HapticPlayer {
  final calls = <HapticCue>[];
  @override
  Future<void> play(HapticCue cue) async {
    calls.add(cue);
  }
}

void main() {
  testWidgets(
    'audition categories stop one another and master-off cancels the cadence',
    (tester) async {
      final sounds = _Sounds(), haptics = _Haptics();
      final service = FeedbackService(
        soundPlayer: sounds,
        hapticPlayer: haptics,
      );
      service.setForeground(true);
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(FakeAppPrefs()),
          feedbackServiceProvider.overrideWithValue(service),
        ],
      );
      final subscription = app.listen(soundAuditionProvider, (_, _) {});
      final audition = app.read(soundAuditionProvider.notifier);
      audition.toggle(SoundCue.tick);
      expect(sounds.calls.map((c) => c.$2), [SoundCue.tick]);
      await tester.pump(const Duration(milliseconds: 2100));
      expect(sounds.calls, hasLength(3));
      audition.toggle(SoundCue.chime);
      await tester.pump(const Duration(seconds: 6));
      expect(sounds.calls.map((c) => c.$2), [
        SoundCue.tick,
        SoundCue.tick,
        SoundCue.tick,
        SoundCue.chime,
      ]);
      audition.toggle(SoundCue.finish);
      expect(sounds.calls.last.$2, SoundCue.finish);
      expect(haptics.calls, isEmpty);
      audition.toggle(SoundCue.tick);
      final count = sounds.calls.length;
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(sound: false));
      await tester.pump(const Duration(seconds: 6));
      expect(sounds.calls.length, count);
      expect(app.read(soundAuditionProvider), isNull);
      expect(sounds.stops, contains('preview'));
      subscription.close();
      app.dispose();
      await service.dispose();
    },
  );

  testWidgets(
    'leaving a timer scope stops its sound and cancels its second strong impact',
    (tester) async {
      final sounds = _Sounds(), haptics = _Haptics();
      final service = FeedbackService(
        soundPlayer: sounds,
        hapticPlayer: haptics,
      );
      service.configure(
        sound: true,
        haptics: true,
        scopes: const {'pomodoro': FeedbackOptions()},
      );
      service.setForeground(true);
      service.play(FeedbackCue.finish, theme: 'yike/water', scope: 'pomodoro');
      expect(haptics.calls, [HapticCue.heavy]);
      service.stopScope('pomodoro');
      await tester.pump(const Duration(milliseconds: 200));
      expect(sounds.stops, contains('pomodoro'));
      expect(haptics.calls, [HapticCue.heavy]);
      await service.dispose();
    },
  );

  testWidgets(
    'timer visibility follows root, mode and nested modal purpose without replay',
    (tester) async {
      final sounds = _Sounds(), haptics = _Haptics();
      final service = FeedbackService(
        soundPlayer: sounds,
        hapticPlayer: haptics,
      );
      var now = DateTime(2026, 10, 24, 12);
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(FakeAppPrefs()),
          notificationAdapterProvider.overrideWithValue(FakeNotifications()),
          feedbackServiceProvider.overrideWithValue(service),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: app, child: const PbApp()),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final visibility = app.read(timerFeedbackVisibilityProvider);
      final feedback = app.read(focusFeedbackProvider);
      void complete(TimerMode mode) =>
          feedback.completed(FocusCompletion('event', TimerStage.focus, mode));
      expect(visibility.allows(TimerMode.pomodoro), isTrue);
      complete(TimerMode.countdown);
      expect(sounds.calls, isEmpty);
      complete(TimerMode.pomodoro);
      expect(sounds.calls, hasLength(1));
      app.read(focusActionsProvider).switchMode(TimerMode.stopwatch);
      await tester.pump();
      expect(sounds.stops, contains('pomodoro'));
      expect(visibility.allows(TimerMode.stopwatch), isTrue);
      final actions = app.read(focusActionsProvider);
      actions.start();
      now = now.add(const Duration(seconds: 2));
      final id = app.read(focusDataProvider).session!.id;
      final beforeLap = haptics.calls.length;
      expect(
        actions.command(TimerMode.stopwatch, id, FocusCommand.lap),
        isTrue,
      );
      expect(haptics.calls.length, beforeLap + 1);
      expect(
        actions.command(TimerMode.stopwatch, 'old-session', FocusCommand.pause),
        isFalse,
      );
      expect(app.read(focusDataProvider).session!.status, TimerStatus.running);
      final closedPanel = Completer<void>(), closedConfirm = Completer<void>();
      final activity = app.read(popupActivityProvider.notifier);
      final panel = activity.track(() => closedPanel.future, timerPanel: true);
      expect(visibility.allows(TimerMode.stopwatch), isTrue);
      complete(TimerMode.stopwatch);
      expect(sounds.calls, hasLength(2));
      final confirm = activity.track(() => closedConfirm.future);
      expect(visibility.allows(TimerMode.stopwatch), isFalse);
      complete(TimerMode.stopwatch);
      expect(sounds.calls, hasLength(2));
      closedConfirm.complete();
      await confirm;
      expect(visibility.allows(TimerMode.stopwatch), isTrue);
      closedPanel.complete();
      await panel;
      app.read(rootTabProvider.notifier).set(1);
      complete(TimerMode.stopwatch);
      expect(sounds.calls, hasLength(2));
      app.read(rootTabProvider.notifier).set(0);
      await tester.pump();
      expect(sounds.calls, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await service.dispose();
      await tester.pump();
    },
  );

  test(
    'inspection selection follows master, optional habit scope and foreground without sound',
    () async {
      final sounds = _Sounds(), haptics = _Haptics();
      final service = FeedbackService(
        soundPlayer: sounds,
        hapticPlayer: haptics,
      );
      service.setForeground(true);
      service.configure(
        sound: true,
        haptics: true,
        scopes: const {'habits': FeedbackOptions(haptics: false)},
      );
      service.select();
      service.select(scope: 'habits');
      expect(haptics.calls, [HapticCue.selection]);
      expect(sounds.calls, isEmpty);
      service.configure(
        sound: true,
        haptics: false,
        scopes: const {'habits': FeedbackOptions()},
      );
      service.select();
      service.select(scope: 'habits');
      expect(haptics.calls, hasLength(1));
      service.configure(
        sound: true,
        haptics: true,
        scopes: const {'habits': FeedbackOptions()},
      );
      service.select(scope: 'habits');
      expect(haptics.calls, hasLength(2));
      service.setForeground(false);
      service.select();
      expect(haptics.calls, hasLength(2));
      await service.dispose();
    },
  );

  test(
    'settings audition plays theme finish without local gates or haptics; master and lifecycle still gate it',
    () async {
      final sounds = _Sounds(), haptics = _Haptics();
      final service = FeedbackService(
        soundPlayer: sounds,
        hapticPlayer: haptics,
      );
      service.setForeground(true);
      service.configure(
        sound: true,
        haptics: true,
        scopes: const {'countdown': FeedbackOptions(sound: false)},
      );
      service.previewFinish(theme: 'yike/water');
      expect(sounds.calls, [('yike/water', SoundCue.finish)]);
      expect(haptics.calls, isEmpty);
      service.configure(sound: false, haptics: true, scopes: const {});
      service.previewFinish(theme: 'yike/mechanical');
      service.configure(sound: true, haptics: true, scopes: const {});
      service.setForeground(false);
      service.previewFinish(theme: 'yike/mechanical');
      expect(sounds.calls, hasLength(1));
      await service.dispose();
    },
  );
}
