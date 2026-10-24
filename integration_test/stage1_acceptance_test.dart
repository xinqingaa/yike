// Temporary stage 1 native UI/audio-load acceptance. Remove after user acceptance.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yike/app/app.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/feedback/feedback_service.dart';
import 'package:yike/common/feedback/sound_player.dart';
import 'package:yike/common/overlay/app_pop.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/router/router.dart';
import 'package:yike/storage/providers.dart';
import '../test/support/fake_app_prefs.dart';
import '../test/support/pump_presentation.dart';
import '../test/support/stage1_feedback.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final file = File('${Directory.systemTemp.path}/yike-stage1-$name.png');
      await file.writeAsBytes(await binding.takeScreenshot(name));
      debugPrint('YIKE_STAGE1_SCREENSHOT=${file.path}');
    });
    expect(tester.takeException(), isNull);
  }

  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final mode in ['light', 'dark']) {
      testWidgets('$theme $mode feedback settings and native asset load', (
        tester,
      ) async {
        final sound = SoLoudSoundPlayer();
        // Native audio resources are real; impact calls are checked in the unit
        // script. A simulator cannot establish a user's actual tactile response.
        final service = FeedbackService(
          soundPlayer: sound,
          hapticPlayer: RecordingHapticPlayer(),
        );
        final disk = FakeAppPrefs({
          'theme_pack': 'yike/$theme',
          'theme_mode': mode,
        });
        var now = DateTime(2026, 10, 24, 12);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              appPrefsProvider.overrideWithValue(disk),
              feedbackServiceProvider.overrideWithValue(service),
              clockProvider.overrideWithValue(() => now),
            ],
            child: const PbApp(),
          ),
        );
        await pumpPresentation(tester);
        await tester.runAsync(service.prepare);
        expect(
          sound.ready,
          isTrue,
          reason:
              'Native engine, ambient session and nine WAV assets must load',
        );
        appNavigatorKey.currentState!.pushNamed(AppRoutes.settings);
        await pumpPresentation(tester);
        final app = ProviderScope.containerOf(
          tester.element(find.byType(YikeSettingsPage)),
        );
        Future<void> reveal(String key) async {
          await tester.ensureVisible(find.byKey(ValueKey(key)));
          await pumpPresentation(tester);
        }

        await reveal('stopwatch/beatMinutes');
        expect(find.byKey(const ValueKey('feedback/haptics')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('stopwatch/secondTick')),
          findsOneWidget,
        );
        await capture(tester, '$theme-$mode-feedback');
        await reveal('feedback/sound');
        await tester.tap(find.byKey(const ValueKey('feedback/sound')));
        await pumpPresentation(tester);
        expect(app.read(timingPreferencesProvider).sound, isFalse);
        expect(
          tester
              .widget<CommonListCell>(
                find.byKey(const ValueKey('stopwatch/secondTick')),
              )
              .disabled,
          isTrue,
        );
        await reveal('feedback/sound');
        await tester.tap(find.byKey(const ValueKey('feedback/sound')));
        await pumpPresentation(tester);
        expect(app.read(timingPreferencesProvider).sound, isTrue);
        await reveal('countdown/beatMinutes');
        await tester.tap(find.byKey(const ValueKey('countdown/beatMinutes')));
        await pumpPresentation(tester);
        await tester.tap(find.text('10 分钟').last);
        await pumpPresentation(tester);
        expect(
          app.read(timingPreferencesProvider).countdownFeedback.beatMinutes,
          10,
        );
        await capture(tester, '$theme-$mode-interval');
        await tester.tap(find.byTooltip('关闭').last);
        await pumpPresentation(tester);
        appNavigatorKey.currentState!.pop();
        await pumpPresentation(tester);
        final actions = app.read(focusActionsProvider);
        actions.switchMode(TimerMode.stopwatch);
        actions.start();
        await pumpPresentation(tester);
        for (var lap = 0; lap < 8; lap++) {
          now = now.add(const Duration(seconds: 2));
          actions.lap();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          expect(tester.takeException(), isNull);
        }
        actions.pause();
        await pumpPresentation(tester);
        await capture(tester, '$theme-$mode-laps');
        await AppPop.clearToasts();
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPresentation(tester);
        await tester.runAsync(service.dispose);
        debugPrint(
          'YIKE_STAGE1_NATIVE=$theme-$mode UI and native audio preload passed; listening and physical haptics require user acceptance',
        );
      });
    }
  }
}
