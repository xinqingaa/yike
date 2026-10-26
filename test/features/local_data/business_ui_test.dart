import '../../support/dial_finder.dart';
import '../../support/pump_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yike/app/app.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/overlay/duration_sheet.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/focus_models.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/habits/pages/habit_editor.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/storage/app_prefs.dart';
import 'package:yike/theme/ts.dart';
import '../../yike_ui_test.dart' show pumpYike, navigateTab;
import 'local_data_test.dart' show FaultPrefs;

void main() {
  testWidgets(
    'failed timing auto-save keeps the sheet and retries the same configuration',
    (tester) async {
      final disk = FaultPrefs();
      var app = await pumpYike(tester, preferences: disk);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      await tester.tap(find.text('专注时长'));
      await pumpPresentation(tester);
      disk.failWrite = true;
      final old = disk.values[PrefsKey.snapshot.storageKey];
      await tester.tap(
        find.descendant(
          of: find.byType(ListWheelScrollView).first,
          matching: find.text('26'),
        ),
      );
      await pumpPresentation(tester);
      expect(find.byType(DurationSheetBody), findsOneWidget);
      expect(find.text('确认'), findsNothing);
      expect(find.text('尚未保存，请重试；关闭后可能丢失'), findsOneWidget);
      expect(disk.values[PrefsKey.snapshot.storageKey], old);
      expect(app.read(timingPreferencesProvider).focusSeconds, 1560);
      // Auto-save sheets close explicitly; the persistent status retries the
      // already accepted value without changing the configuration again.
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
      disk.failWrite = false;
      await tester.tap(find.text('重试保存'));
      await pumpPresentation(tester);
      expect(find.byType(DurationSheetBody), findsNothing);
      expect(app.read(localDataProvider).writeError, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app = await pumpYike(tester, preferences: disk);
      expect(app.read(focusViewProvider).target, 26 * 60);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'countdown completion updates review and cold restart keeps one result',
    (tester) async {
      var now = DateTime(2026, 10, 16, 12);
      final disk = FaultPrefs();
      var app = await pumpYike(tester, preferences: disk, clock: () => now);
      app.read(focusActionsProvider).switchMode(TimerMode.countdown);
      app.read(focusActionsProvider).selectCountdown(1);
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('focus-primary')));
      now = now.add(const Duration(seconds: 10));
      app.read(clockPulseProvider.notifier).refresh();
      await pumpPresentation(tester);
      expect(dialDigits('00:00'), findsOneWidget);
      expect(app.read(focusRecordsProvider).single.seconds, 1);
      await navigateTab(tester, '回顾');
      expect(find.text('1 秒'), findsWidgets);
      expect(find.text('1 次'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      now = now.add(const Duration(days: 1));
      app = await pumpYike(tester, preferences: disk, clock: () => now);
      expect(
        app.read(focusDataProvider).sessionFor(TimerMode.countdown)!.status,
        TimerStatus.finished,
      );
      app.read(focusActionsProvider).switchMode(TimerMode.countdown);
      await pumpPresentation(tester);
      expect(app.read(focusRecordsProvider), hasLength(1));
      await tester.tap(find.byKey(const ValueKey('focus-primary')));
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).ready, isTrue);
      expect(app.read(focusRecordsProvider), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'short record cancel stays paused; acceptance creates exactly one record',
    (tester) async {
      var now = DateTime(2026, 10, 16, 12);
      final app = await pumpYike(tester, clock: () => now);
      await tester.tap(find.text('正计时'));
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('focus-primary')));
      now = now.add(const Duration(seconds: 5));
      app.read(clockPulseProvider.notifier).refresh();
      await pumpPresentation(tester);
      await tester.tap(find.text('暂停'));
      await pumpPresentation(tester);
      await tester.tap(find.text('结束并记录'));
      await pumpPresentation(tester);
      expect(find.text('记录这次短时专注？'), findsOneWidget);
      await tester.tap(find.text('暂不结束'));
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).paused, isTrue);
      expect(app.read(focusViewProvider).seconds, 5);
      expect(app.read(focusRecordsProvider), isEmpty);
      await tester.tap(find.text('结束并记录'));
      await pumpPresentation(tester);
      await tester.tap(find.text('仍然记录'));
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).ready, isTrue);
      expect(app.read(focusRecordsProvider).single.seconds, 5);
      app.read(focusActionsProvider).finish();
      expect(app.read(focusRecordsProvider), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'natural short pomodoro prompts once, cancellation keeps completed round',
    (tester) async {
      var now = DateTime(2026, 10, 16, 12);
      final app = await pumpYike(tester, clock: () => now);
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(focusSeconds: 60, threshold: 180));
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('focus-primary')));
      now = now.add(const Duration(seconds: 65));
      app.read(clockPulseProvider.notifier).refresh();
      await pumpPresentation(tester);
      expect(find.text('记录这次短时专注？'), findsOneWidget);
      expect(app.read(focusDataProvider).cycles, 1);
      await tester.tap(find.text('暂不结束'));
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).finished, isTrue);
      expect(app.read(focusRecordsProvider), isEmpty);
      await tester.tap(find.byKey(const ValueKey('focus-primary')));
      await pumpPresentation(tester);
      expect(find.text('记录这次短时专注？'), findsOneWidget);
      await tester.tap(find.text('仍然记录'));
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).stage, TimerStage.shortBreak);
      expect(app.read(focusRecordsProvider).single.seconds, 60);
      expect(app.read(focusDataProvider).cycles, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed habit save keeps editor and retries the same identity', (
    tester,
  ) async {
    final disk = FaultPrefs();
    final app = await pumpYike(tester, preferences: disk);
    await navigateTab(tester, '打卡');
    await tester.tap(find.byTooltip('新建习惯'));
    await pumpPresentation(tester);
    await tester.enterText(find.byType(TextField).first, '散步');
    disk.failWrite = true;
    await tester.tap(find.byKey(const ValueKey('habit-save')));
    await pumpPresentation(tester);
    expect(find.byType(HabitEditor), findsOneWidget);
    expect(find.textContaining('尚未保存'), findsWidgets);
    expect(app.read(habitsProvider).where((h) => h.name == '散步'), hasLength(1));
    final id = app.read(habitsProvider).last.id;
    disk.failWrite = false;
    await tester.tap(find.byKey(const ValueKey('habit-save')));
    await pumpPresentation(tester);
    expect(find.byType(HabitEditor), findsNothing);
    expect(app.read(habitsProvider).last.id, id);
    expect(app.read(habitsProvider), hasLength(5));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'corrupt storage shows a blocking recovery state and preserves bytes',
    (tester) async {
      final disk = FaultPrefs();
      disk.values[PrefsKey.snapshot.storageKey] = '{corrupt';
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      // The helper expects Home, so mount this recovery case directly.
      await tester.pumpWidget(recoveryApp(disk));
      await pumpPresentation(tester);
      expect(find.text('重试读取'), findsOneWidget);
      expect(find.text('开始专注'), findsNothing);
      await tester.tap(find.text('重试读取'));
      await pumpPresentation(tester);
      expect(disk.values[PrefsKey.snapshot.storageKey], '{corrupt');
      expect(find.text('重置本机数据'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reset restores full local data and appearance then survives reopen',
    (tester) async {
      var now = DateTime(2026, 10, 16, 12);
      final disk = FaultPrefs();
      var app = await pumpYike(tester, preferences: disk, clock: () => now);
      final a = app.read(focusActionsProvider);
      a.switchMode(TimerMode.countdown);
      a.selectCountdown(1);
      a.start();
      now = now.add(const Duration(seconds: 1));
      app.read(clockPulseProvider.notifier).refresh();
      app.read(habitsProvider.notifier).toggle('habit-water', '2026-10-16');
      app.read(themePackProvider.notifier).select('yike/water');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await pumpPresentation(tester);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      await tester.scrollUntilVisible(
        find.text('重置所有数据'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(YikeSettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await pumpPresentation(tester);
      await tester.tap(find.text('重置所有数据'));
      await pumpPresentation(tester);
      await tester.tap(find.text('取消'));
      await pumpPresentation(tester);
      expect(app.read(focusRecordsProvider), hasLength(1));
      await tester.tap(find.text('重置所有数据'));
      await pumpPresentation(tester);
      await tester.tap(find.text('确认重置'));
      await pumpPresentation(tester);
      expect(app.read(rootTabProvider), 0);
      expect(app.read(focusRecordsProvider), isEmpty);
      expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
      expect(app.read(focusViewProvider).ready, isTrue);
      expect(app.read(focusDataProvider).cycles, 0);
      expect(app.read(habitsProvider), hasLength(4));
      expect(app.read(habitsProvider).expand((h) => h.dates), isEmpty);
      expect(app.read(themePackProvider).id, 'yike/mechanical');
      expect(app.read(themeModeProvider), ThemeMode.system);
      await tester.pumpWidget(const SizedBox.shrink());
      app = await pumpYike(tester, preferences: disk, clock: () => now);
      expect(app.read(focusRecordsProvider), isEmpty);
      expect(app.read(habitsProvider), hasLength(4));
      expect(app.read(focusViewProvider).seconds, 1500);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cross-day week counts one session and month counts two focus days',
    (tester) async {
      final app = await pumpYike(tester);
      app
          .read(localDataProvider.notifier)
          .commit(
            app
                .read(localDataProvider)
                .data
                .copyWith(
                  focus: FocusData(
                    records: [
                      FocusRecord(
                        sessionId: 'one-session',
                        mode: TimerMode.stopwatch,
                        startedAt: DateTime(2026, 10, 15, 23, 59, 30),
                        elapsedMs: 90000,
                        days: const {'2026-10-15': 30000, '2026-10-16': 60000},
                      ),
                    ],
                  ),
                ),
          );
      await navigateTab(tester, '回顾');
      expect(find.text('1 次'), findsWidgets);
      expect(find.text('1 分钟 30 秒'), findsOneWidget);
      await tester.tap(find.text('月'));
      await pumpPresentation(tester);
      expect(find.text('2 天'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('2026-10-16'));
      await pumpPresentation(tester);
      await tester.ensureVisible(find.text('查看当日记录'));
      await tester.tap(find.text('查看当日记录'));
      await pumpPresentation(tester);
      expect(find.text('23:59'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('day-record-duration-0')),
          matching: find.text('1分'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('archived list waits for Sheet dismissal before opening detail', (
    tester,
  ) async {
    final app = await pumpYike(tester);
    final water = app.read(habitsProvider).first;
    app
        .read(habitsProvider.notifier)
        .save(water.copyWith(archivedOn: '2026-10-16'));
    await navigateTab(tester, '打卡');
    await tester.ensureVisible(find.byTooltip('打开已归档习惯'));
    await tester.tap(find.byTooltip('打开已归档习惯'));
    await pumpPresentation(tester);
    await tester.tap(find.text('喝够 8 杯水'));
    await pumpPresentation(tester);
    expect(find.text('最近一年'), findsWidgets);
    expect(find.text('恢复习惯'), findsOneWidget);
    await tester.tap(find.text('恢复习惯'));
    await pumpPresentation(tester);
    expect(app.read(habitsProvider).first.archived, isFalse);
    expect(find.byKey(const ValueKey('check-habit-water')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget recoveryApp(FaultPrefs disk) => ProviderScope(
  overrides: [appPrefsProvider.overrideWithValue(disk)],
  child: const PbApp(),
);
