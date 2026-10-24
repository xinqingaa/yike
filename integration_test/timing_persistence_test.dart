import '../test/support/dial_finder.dart';
import 'dart:io' show pid;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yike/app/startup.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/home/pages/home_page.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/storage/mmkv_app_prefs.dart';

// Run write and read as separate application processes on the same device.
const phase = String.fromEnvironment(
  'YIKE_STORAGE_PHASE',
  defaultValue: 'write',
);
const storageId = 'yike_timing_integration';

Future<void> tapWheel(WidgetTester tester, int column, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ListWheelScrollView).at(column),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openSetting(WidgetTester tester, String label) async {
  final scroll = find
      .descendant(
        of: find.byType(YikeSettingsPage),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(find.text(label), 120, scrollable: scroll);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void verifyValues(TimingPreferences prefs) {
  expect(prefs.focusSeconds, 1560);
  expect(prefs.interval, 3);
  expect(prefs.threshold, 5);
  expect(prefs.sound, false);
  expect(prefs.presets, [181, null, 600, 1200]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('timing settings persist across process restart ($phase)', (
    tester,
  ) async {
    expect(['write', 'read'], contains(phase));
    debugPrint('YIKE_STORAGE_PHASE=$phase PID=$pid');
    final prefs = await MmkvAppPrefs.open(id: storageId);
    if (phase == 'write') {
      // Only the isolated integration instance is cleared.
      prefs.remove(localDataPrefs);
    } else {
      final saved = prefs.read(localDataPrefs);
      expect(
        saved,
        isNotNull,
        reason: 'Run write phase first; do not erase the app container.',
      );
      verifyValues(saved!.focus.preferences);
    }
    await tester.pumpWidget(AppStartup(openPreferences: () async => prefs));
    await tester.pumpAndSettle();
    final app = ProviderScope.containerOf(
      tester.element(find.byType(YikeHomePage)),
    );
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    if (phase == 'write') {
      await openSetting(tester, '专注时长');
      await tapWheel(tester, 1, '26');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      await openSetting(tester, '长休间隔');
      await tapWheel(tester, 0, '3');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      await openSetting(tester, '常用倒计时');
      await tester.tap(find.text('常用 1'));
      await tester.pumpAndSettle();
      await tapWheel(tester, 2, '01');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('常用 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空此项'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await openSetting(tester, '短时记录确认阈值');
      await tapWheel(tester, 0, '5 秒');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(YikeSettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('提示音'),
        100,
        scrollable: scroll,
      );
      await tester.tap(find.byType(CommonSwitch));
      await tester.pumpAndSettle();
    }
    verifyValues(app.read(timingPreferencesProvider));
    expect(app.read(localDataProvider).writeError, isNull);
    expect(app.read(localDataProvider).readError, isNull);
    verifyValues(prefs.read(localDataPrefs)!.focus.preferences);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(app.read(focusViewProvider).target, 26 * 60);
    expect(dialDigits('26:00'), findsOneWidget);
    // Do not explicitly flush or close before process termination: exercise
    // ordinary application writes rather than a special test-only save path.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
