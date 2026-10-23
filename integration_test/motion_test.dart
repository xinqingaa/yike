import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yike/app/app.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/overlay/app_pop.dart';
import 'package:yike/common/time.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/home/pages/home_page.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/theme/ts.dart';

import '../test/features/local_data/local_data_test.dart' show FaultPrefs;
import '../test/support/pump_presentation.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final file = File('${Directory.systemTemp.path}/yike-motion-$name.png');
      await file.writeAsBytes(await binding.takeScreenshot(name));
      debugPrint('YIKE_MOTION_SCREENSHOT=${file.path}');
    });
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await pumpPresentation(tester);
  }

  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final reduced in [false, true]) {
      testWidgets(
        '$theme ${reduced ? 'reduced' : 'normal'} native motion process',
        (tester) async {
          final name = '$theme-${reduced ? 'reduced' : 'normal'}';
          final disk = FaultPrefs();
          disk.values.addAll({
            'theme_pack': 'yike/$theme',
            'theme_mode': 'light',
          });
          var offset = Duration.zero;
          final elapsed = Stopwatch()..start();
          DateTime now() =>
              DateTime.utc(2026, 10, 16, 12).add(offset + elapsed.elapsed);
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reduced);
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                appPrefsProvider.overrideWithValue(disk),
                clockProvider.overrideWithValue(now),
                todayProvider.overrideWithValue(DateTime.utc(2026, 10, 16)),
              ],
              child: const PbApp(),
            ),
          );
          await pumpPresentation(tester);
          final app = ProviderScope.containerOf(
            tester.element(find.byType(YikeHomePage)),
          );
          final actions = app.read(focusActionsProvider);
          await tap(tester, find.text('正计时'));
          await tap(tester, find.text('开始计时'));
          for (var lap = 0; lap < 3; lap++) {
            offset += const Duration(seconds: 2);
            await tap(tester, find.text('计圈'));
          }
          await capture(tester, '$name-laps');
          await tap(tester, find.text('暂停'));
          expect(app.read(focusViewProvider).paused, isTrue);
          actions.discard();
          actions.switchMode(TimerMode.countdown);
          actions.selectCountdown(2);
          await pumpPresentation(tester);
          actions.start();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await capture(tester, '$name-counting');
          await tester.pump(const Duration(seconds: 2));
          await tester.pump(const Duration(milliseconds: 80));
          await capture(tester, '$name-completion');
          expect(app.read(focusViewProvider).finished, isTrue);
          await tap(
            tester,
            find.descendant(
              of: find.byType(CommonBottomNav),
              matching: find.text('打卡'),
            ),
          );
          await tester.tap(find.byKey(const ValueKey('check-habit-water')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 55));
          await capture(tester, '$name-checkin-middle');
          await tap(tester, find.byKey(const ValueKey('check-habit-water')));
          await tap(tester, find.byKey(const ValueKey('check-habit-water')));
          await tap(
            tester,
            find.descendant(
              of: find.byType(CommonBottomNav),
              matching: find.text('回顾'),
            ),
          );
          await tester.tap(find.byTooltip('上一期'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 70));
          await capture(tester, '$name-period-middle');
          await pumpPresentation(tester);
          await tap(tester, find.text('月'));
          await capture(tester, '$name-month');
          disk.failWrite = true;
          app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
          await pumpPresentation(tester);
          expect(find.byKey(const ValueKey('unsaved-status')), findsOneWidget);
          await capture(tester, '$name-unsaved-dark');
          AppSheetActions<void>? modal;
          final close = AppPop.sheet<void>(
            tester.element(find.byType(YikeHomePage)),
            title: '保存状态检查',
            builder: (_, actions) {
              modal = actions;
              return const Text('当前操作优先，未保存提示暂挂起');
            },
          );
          await pumpPresentation(tester);
          expect(find.byKey(const ValueKey('unsaved-status')), findsNothing);
          unawaited(modal!.dismiss());
          await pumpPresentation(tester);
          await close;
          expect(find.byKey(const ValueKey('unsaved-status')), findsOneWidget);
          disk.failWrite = false;
          await tap(tester, find.text('重试保存'));
          expect(find.byKey(const ValueKey('unsaved-status')), findsNothing);
          debugPrint(
            'YIKE_MOTION_PROCESS=$name mode=${kProfileMode ? 'profile' : 'debug'} platform=${Platform.operatingSystem} passed',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpPresentation(tester);
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        },
      );
    }
  }
}
