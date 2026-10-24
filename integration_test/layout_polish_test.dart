import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yike/app/app.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/time.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/home/pages/home_page.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/theme/ts.dart';

import '../test/support/fake_app_prefs.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  Future<TestGesture> press(WidgetTester tester, Finder finder) async {
    final gesture = TestGesture(
      pointer: 1000,
      dispatcher: (event) async {
        binding.handlePointerEventForSource(
          event,
          source: TestBindingEventSource.device,
        );
      },
    );
    await gesture.down(tester.getCenter(finder), view: tester.view);
    return gesture;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final file = File('${Directory.systemTemp.path}/yike-polish-$name.png');
      await file.writeAsBytes(await binding.takeScreenshot(name));
      debugPrint('YIKE_POLISH_SCREENSHOT=${file.path}');
    });
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> root(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(
      of: find.byType(CommonBottomNav),
      matching: find.text(label),
    ),
  );

  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets('$theme native aligned controls and review actions', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 23, 12);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(
              FakeAppPrefs({
                'theme_pack': 'yike/$theme',
                'theme_mode': 'light',
              }),
            ),
            todayProvider.overrideWithValue(DateTime.utc(2026, 10, 23)),
            clockProvider.overrideWithValue(() => now),
            focusRecordsProvider.overrideWithValue(const [
              FocusRecordView(
                date: '2026-10-23',
                time: '08:30',
                seconds: 1500,
                mode: TimerMode.pomodoro,
              ),
              FocusRecordView(
                date: '2026-10-23',
                time: '09:15',
                seconds: 3605,
                mode: TimerMode.stopwatch,
              ),
              FocusRecordView(
                date: '2026-10-23',
                time: '10:20',
                seconds: 5.5,
                mode: TimerMode.countdown,
              ),
            ]),
          ],
          child: const PbApp(),
        ),
      );
      if (Platform.isAndroid) {
        await tester.runAsync(binding.convertFlutterSurfaceToImage);
      }
      await tester.pumpAndSettle();
      final app = ProviderScope.containerOf(
        tester.element(find.byType(YikeHomePage)),
      );
      app.read(habitsProvider.notifier).replace([
        HabitViewData(
          id: 'walk',
          name: '午后散步与肩颈拉伸，离开屏幕好好休息',
          created: '2026-10-01',
          dates: const {'2026-10-23'},
        ),
        HabitViewData(
          id: 'read',
          name: '阅读',
          created: '2026-10-01',
          dates: const {'2026-10-23'},
        ),
      ]);
      await tap(tester, find.text('倒计时'));
      expect(app.read(focusViewProvider).mode, TimerMode.countdown);
      expect(
        tester.getRect(find.byKey(const ValueKey('focus-primary')).last).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(CommonBottomNav)).top),
      );
      await capture(tester, '$theme-countdown');
      await tap(tester, find.byKey(const ValueKey('countdown-edit')));
      await capture(tester, '$theme-duration');
      await tap(tester, find.byTooltip('关闭'));
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await capture(tester, '$theme-countdown-dark');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await tap(tester, find.text('正计时'));
      await tap(tester, find.text('开始计时'));
      for (var i = 0; i < 12; i++) {
        now = now.add(Duration(seconds: i.isEven ? 65 : 330));
        app.read(focusActionsProvider).lap();
      }
      now = now.add(const Duration(seconds: 123));
      app.read(clockPulseProvider.notifier).refresh();
      expect(
        tester.getRect(find.byKey(const ValueKey('focus-primary')).last).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(CommonBottomNav)).top),
      );
      await capture(tester, '$theme-laps');
      expect(
        tester.getRect(find.widgetWithText(CommonButton, '取消计时')).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(CommonBottomNav)).top),
      );
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await capture(tester, '$theme-laps-dark');
      app.read(focusActionsProvider).discard();
      app.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await root(tester, '回顾');
      final day = find.byKey(const ValueKey('review-day-2026-10-23'));
      await tester.ensureVisible(day);
      final weekPress = await press(tester, day);
      await capture(tester, '$theme-week-pressed');
      await weekPress.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommonPressableSurface>(
              find.byKey(const ValueKey('day-next')),
            )
            .onPressed,
        isNull,
      );
      await capture(tester, '$theme-day-records');
      await tap(tester, find.byTooltip('关闭'));
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      await tap(tester, day);
      await capture(tester, '$theme-day-records-dark');
      await tap(tester, find.byTooltip('关闭'));
      app.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await tester.pumpAndSettle();
      await tap(tester, day);
      await tap(tester, find.byKey(const ValueKey('day-previous')));
      await capture(tester, '$theme-day-empty');
      await tap(tester, find.byTooltip('关闭'));
      await tap(tester, find.text('月'));
      final monthDay = find.bySemanticsLabel('2026-10-23');
      await tester.ensureVisible(monthDay);
      final monthPress = await press(tester, monthDay);
      await capture(tester, '$theme-month-pressed');
      await monthPress.up();
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('关闭'));
      await root(tester, '专注');
      await tap(tester, find.byTooltip('设置'));
      final scroll = find
          .descendant(
            of: find.byType(YikeSettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('常用倒计时'),
        120,
        scrollable: scroll,
      );
      await tap(tester, find.text('常用倒计时'));
      expect(find.bySemanticsLabel('第1步，共2步'), findsNothing);
      await capture(tester, '$theme-flow-default');
      await tap(tester, find.byTooltip('关闭'));
      expect(tester.takeException(), isNull);
    });
  }
}
