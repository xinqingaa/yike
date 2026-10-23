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

// Only in-memory storage is used. Native screenshot paths are printed for QA.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.utc(2026, 10, 23);
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final bytes = await binding.takeScreenshot(name);
      final file = File(
        '${Directory.systemTemp.path}/yike-experience-$name.png',
      );
      await file.writeAsBytes(bytes);
      debugPrint('YIKE_SCREENSHOT=${file.path}');
    });
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> root(WidgetTester tester, String title) => tap(
    tester,
    find.descendant(
      of: find.byType(CommonBottomNav),
      matching: find.text(title),
    ),
  );

  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets('$theme native sheets, year grid and empty review', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(
              FakeAppPrefs({
                'theme_pack': 'yike/$theme',
                'theme_mode': 'light',
              }),
            ),
            todayProvider.overrideWithValue(today),
            clockProvider.overrideWithValue(
              () => DateTime.utc(2026, 10, 23, 12),
            ),
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
      await tap(tester, find.text('开始专注'));
      await tap(tester, find.text('正计时'));
      expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
      await capture(tester, '$theme-mode-request');
      await tap(tester, find.byTooltip('关闭'));
      expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
      expect(app.read(focusViewProvider).status, TimerStatus.running);
      await tap(tester, find.byTooltip('设置'));
      await tap(tester, find.text('专注时长'));
      await capture(tester, '$theme-duration');
      await tap(tester, find.byTooltip('关闭'));
      final settingsScroll = find
          .descendant(
            of: find.byType(YikeSettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('常用倒计时'),
        120,
        scrollable: settingsScroll,
      );
      await tap(tester, find.text('常用倒计时'));
      await capture(tester, '$theme-flow');
      await tap(tester, find.byTooltip('关闭'));
      await tap(tester, find.byTooltip('返回'));
      app.read(focusActionsProvider).discard();
      await root(tester, '打卡');
      await tap(tester, find.byKey(const ValueKey('habit-detail-habit-water')));
      await capture(tester, '$theme-new-habit');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await capture(tester, '$theme-new-habit-dark');
      await tap(tester, find.byTooltip('返回'));
      app.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await root(tester, '回顾');
      expect(find.text('这一周还没有记录'), findsOneWidget);
      await capture(tester, '$theme-empty-week');
      final sourceTop = tester.getTopLeft(find.text('回顾').first);
      await tap(tester, find.byKey(const ValueKey('review-day-2026-10-23')));
      expect(tester.getTopLeft(find.text('回顾').first), sourceTop);
      await capture(tester, '$theme-day-detail');
      await tap(tester, find.byTooltip('关闭'));
      app.read(habitsProvider.notifier).toggle('habit-water', '2026-10-23');
      await capture(tester, '$theme-checkin-week');
      await tap(tester, find.text('月'));
      await capture(tester, '$theme-checkin-month');
      expect(tester.takeException(), isNull);
    });
  }
}
