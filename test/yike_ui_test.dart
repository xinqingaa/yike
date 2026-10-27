import 'support/dial_finder.dart';
import 'support/pump_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/app/app.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/common/widgets/yike/dial.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/review/review.dart';
import 'package:yike/common/time.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/features/focus/focus_models.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'package:yike/features/home/pages/home_page.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/features/habits/pages/habit_editor.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/storage/app_prefs.dart';
import 'support/fake_app_prefs.dart';

Finder focusModeTab(String title) => find.descendant(
  of: find.byType(CommonPrimaryTabs),
  matching: find.text(title),
);

Future<ProviderContainer> pumpYike(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  String theme = 'mechanical',
  String mode = 'light',
  FocusViewData? focus,
  List<FocusRecordView>? records,
  AppPrefs? preferences,
  DateTime Function()? clock,
  bool freshInstall = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final appPreferences =
      preferences ??
      FakeAppPrefs({'theme_pack': 'yike/$theme', 'theme_mode': mode});
  if (!freshInstall) {
    try {
      if (appPreferences.read(localDataPrefs) == null) {
        appPreferences.write(
          localDataPrefs,
          YikeData.initial(
            DateTime.utc(2026, 10, 16),
          ).copyWith(onboardingComplete: true),
        );
      }
    } catch (_) {
      // Tests can provide a deliberately unreadable store.
    }
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(appPreferences),
        todayProvider.overrideWithValue(DateTime.utc(2026, 10, 16)),
        clockProvider.overrideWithValue(
          clock ?? () => DateTime.utc(2026, 10, 16, 12),
        ),
        if (records != null) focusRecordsProvider.overrideWithValue(records),
      ],
      child: const PbApp(),
    ),
  );
  await pumpPresentation(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(YikeHomePage)),
  );
  if (focus != null) {
    final now = DateTime.utc(2026, 10, 16, 12);
    final elapsed =
        (focus.mode == TimerMode.stopwatch
            ? focus.seconds
            : focus.target - focus.seconds) *
        1000;
    container
        .read(localDataProvider.notifier)
        .commit(
          container
              .read(localDataProvider)
              .data
              .copyWith(
                focus: FocusData(
                  mode: focus.mode,
                  countdown: focus.target,
                  sessions: {
                    if (!focus.ready)
                      focus.mode: FocusSession(
                        id: 'fixture-session',
                        mode: focus.mode,
                        stage: focus.stage,
                        status: focus.status,
                        startedAt: now.subtract(
                          Duration(milliseconds: elapsed),
                        ),
                        targetMs: focus.target * 1000,
                        elapsedMs: elapsed,
                        round: focus.round,
                        longRest: false,
                        days: focus.resting
                            ? const {}
                            : {'2026-10-16': elapsed},
                        laps: focus.laps.map((v) => v * 1000).toList(),
                        anchor: focus.status == TimerStatus.running
                            ? now
                            : null,
                      ),
                  },
                ),
              ),
        );
    await pumpPresentation(tester);
  }
  return container;
}

Future<void> navigateTab(WidgetTester tester, String title) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CommonBottomNav),
      matching: find.text(title),
    ),
  );
  await pumpPresentation(tester);
}

void main() {
  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final mode in ['light', 'dark']) {
      testWidgets(
        '$theme $mode roots, settings and editor render without overflow',
        (tester) async {
          await pumpYike(tester, theme: theme, mode: mode);
          expect(dialDigits('25:00'), findsOneWidget);
          await tester.tap(find.byTooltip('设置'));
          await pumpPresentation(tester);
          expect(find.text('跟随系统'), findsOneWidget);
          expect(find.byType(YikeDial), findsNWidgets(3));
          await tester.tap(find.byTooltip('返回'));
          await pumpPresentation(tester);
          await navigateTab(tester, '打卡');
          expect(find.text('喝够 8 杯水'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('check-habit-water')));
          await pumpPresentation(tester);
          expect(find.textContaining('今天 1 / 4'), findsOneWidget);
          await tester.tap(find.byTooltip('新建习惯'));
          await pumpPresentation(tester);
          expect(find.byType(HabitEditor), findsOneWidget);
          expect(
            DefaultTextStyle.of(
              tester.element(find.text('图标')),
            ).style.decoration,
            isNot(TextDecoration.underline),
          );
          await tester.tap(find.byKey(const ValueKey('habit-save')));
          await pumpPresentation(tester);
          expect(find.text('写一个习惯名称'), findsOneWidget);
          await tester.enterText(find.byType(TextField).first, '散步');
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('habit-save')));
          await pumpPresentation(tester);
          await tester.scrollUntilVisible(
            find.text('散步'),
            150,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text('散步'), findsOneWidget);
          await navigateTab(tester, '回顾');
          expect(find.textContaining('1 次'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('switch preserves paused mode and moves official tab indicator', (
    tester,
  ) async {
    await pumpYike(tester);
    await tester.tap(find.text('开始专注'));
    await pumpPresentation(tester);
    await tester.tap(find.text('暂停'));
    await pumpPresentation(tester);
    await tester.tap(focusModeTab('正计时'));
    await pumpPresentation(tester);
    expect(find.text('切换计时模式'), findsNothing);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await tester.tap(focusModeTab('番茄钟'));
    await pumpPresentation(tester);
    expect(find.text('继续'), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('focus modes only change through the top tabs', (tester) async {
    final container = await pumpYike(tester);
    final panels = find.byType(CommonTabView).last;
    await tester.drag(panels, const Offset(-320, 0));
    await pumpPresentation(tester);
    expect(container.read(focusViewProvider).mode, TimerMode.pomodoro);
    // A drag can now adjust time; it must not change the selected mode.
    await tester.tap(focusModeTab('正计时'));
    await pumpPresentation(tester);
    expect(container.read(focusViewProvider).mode, TimerMode.stopwatch);
    expect(dialDigits('00:00'), findsOneWidget);
    await tester.tap(focusModeTab('倒计时'));
    await pumpPresentation(tester);
    expect(container.read(focusViewProvider).mode, TimerMode.countdown);
    expect(find.byKey(const ValueKey('countdown-edit')), findsOneWidget);
    expect(find.text('自定义'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings navigation rows match 53px and accept label and blank-space taps',
    (tester) async {
      await pumpYike(tester);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      final row = find.byKey(const ValueKey('pomodoro/focus'));
      expect(tester.getSize(row).height, closeTo(53, 1));
      await Scrollable.ensureVisible(
        tester.element(find.text('专注时长')),
        alignment: .3,
      );
      await pumpPresentation(tester);
      await tester.tap(find.text('专注时长'));
      await pumpPresentation(tester);
      expect(find.byType(CommonWheelPicker), findsOneWidget);
      expect(find.text('确认'), findsNothing);
      final title = find.text('专注时长').last;
      final start = tester.getTopLeft(title).dy;
      await tester.tap(find.byTooltip('关闭'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(title).dy - start, greaterThan(30));
      await pumpPresentation(tester);
      final bounds = tester.getRect(row);
      await tester.tapAt(Offset(bounds.center.dx, bounds.center.dy));
      await pumpPresentation(tester);
      expect(find.byType(CommonWheelPicker), findsOneWidget);
      expect(find.text('确认'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'habit name navigates independently and editing preserves its identity',
    (tester) async {
      final container = await pumpYike(tester);
      await navigateTab(tester, '打卡');
      await tester.tap(find.byKey(const ValueKey('habit-detail-habit-water')));
      await pumpPresentation(tester);
      await tester.ensureVisible(find.byType(CommonHeatmap));
      await pumpPresentation(tester);
      expect(find.bySemanticsLabel('最近一年完成 0 次'), findsOneWidget);
      expect(container.read(habitsProvider).first.dates, isEmpty);
      await tester.tap(find.text('编辑'));
      await pumpPresentation(tester);
      await tester.enterText(find.byType(TextField).first, '喝够 8 杯水（编辑）');
      await tester.pump();
      await tester.tap(find.text('保存'));
      await pumpPresentation(tester);
      expect(container.read(habitsProvider).first.id, 'habit-water');
      expect(find.text('喝够 8 杯水（编辑）'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await pumpPresentation(tester);
      expect(find.text('喝够 8 杯水（编辑）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'review day browsing stays in period and close retains browsing context',
    (tester) async {
      final container = await pumpYike(
        tester,
        records: const [
          FocusRecordView(
            date: '2026-10-16',
            time: '08:50',
            seconds: 1500,
            mode: TimerMode.pomodoro,
          ),
        ],
      );
      await navigateTab(tester, '回顾');
      await tester.tap(find.text('月'));
      await pumpPresentation(tester);
      await tester.tap(find.bySemanticsLabel('2026-10-16'));
      await pumpPresentation(tester);
      await tester.ensureVisible(find.text('查看当日记录'));
      await tester.tap(find.text('查看当日记录'));
      await pumpPresentation(tester);
      expect(find.text('08:50'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day-previous')));
      await pumpPresentation(tester);
      expect(find.text('这一天没有记录'), findsOneWidget);
      expect(
        container.read(reviewSelectionProvider).lastViewedDate,
        '2026-10-15',
      );
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
      expect(
        container.read(reviewSelectionProvider).lastViewedDate,
        '2026-10-15',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    '320px editor keeps its save action reachable above the keyboard',
    (tester) async {
      await pumpYike(tester, size: const Size(320, 640), theme: 'water');
      await navigateTab(tester, '打卡');
      await tester.tap(find.byTooltip('新建习惯'));
      await pumpPresentation(tester);
      await tester.enterText(find.byType(TextField).first, '拉伸');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await pumpPresentation(tester);
      await tester.ensureVisible(find.text('每周'));
      await tester.tap(find.text('每周'));
      await pumpPresentation(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('habit-save')));
      expect(
        tester.getRect(find.byKey(const ValueKey('habit-save'))).bottom,
        lessThanOrEqualTo(640 - 260),
      );
      await tester.tap(find.byKey(const ValueKey('habit-save')));
      await pumpPresentation(tester);
      tester.view.resetViewInsets();
      expect(find.byType(HabitEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('settings flows preserve slots and reject duplicate durations', (
    tester,
  ) async {
    final container = await pumpYike(tester);
    await tester.tap(find.byTooltip('设置'));
    await pumpPresentation(tester);
    final settingsScroll = find
        .descendant(
          of: find.byType(YikeSettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('countdown/presets')),
      250,
      scrollable: settingsScroll,
    );
    await pumpPresentation(tester);
    await tester.tap(find.byTooltip('打开常用倒计时'));
    await pumpPresentation(tester);
    await tester.tap(find.byKey(const ValueKey('preset-row-0')));
    await pumpPresentation(tester);
    expect(find.text('清空此项'), findsNothing);
    expect(container.read(timingPreferencesProvider).presets.first, 180);
    await tester.tap(find.byKey(const ValueKey('preset-row-1')));
    await pumpPresentation(tester);
    await tester.tap(find.text('清空此项'));
    await pumpPresentation(tester);
    expect(container.read(timingPreferencesProvider).presets, [
      180,
      null,
      600,
      1200,
    ]);
    await tester.tap(find.byKey(const ValueKey('preset-row-1')));
    await pumpPresentation(tester);
    final minutes = find
        .descendant(
          of: find.byKey(const ValueKey('wheel-column-minute')),
          matching: find.byType(ListWheelScrollView),
        )
        .hitTestable();
    await tester.tap(find.descendant(of: minutes, matching: find.text('04')));
    await pumpPresentation(tester);
    expect(container.read(timingPreferencesProvider).presets[1], 240);
    await tester.tap(find.descendant(of: minutes, matching: find.text('03')));
    await pumpPresentation(tester);
    expect(find.text('这个时长已在其它常用项中'), findsOneWidget);
    expect(container.read(timingPreferencesProvider).presets, [
      180,
      240,
      600,
      1200,
    ]);
    await tester.tap(find.byTooltip('关闭'));
    await pumpPresentation(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('general/threshold')),
      -250,
      scrollable: settingsScroll,
    );
    await pumpPresentation(tester);
    await tester.tap(find.byTooltip('打开短时记录确认阈值'));
    await pumpPresentation(tester);
    await tester.tap(find.byTooltip('自定义时长'));
    await pumpPresentation(tester);
    expect(find.text('自定义时长'), findsOneWidget);
    final seconds = find.descendant(
      of: find.byKey(const ValueKey('wheel-column-second')),
      matching: find.byType(ListWheelScrollView),
    );
    await tester.tap(find.descendant(of: seconds, matching: find.text('11')));
    await pumpPresentation(tester);
    expect(container.read(timingPreferencesProvider).threshold, 11);
    await tester.tap(find.byTooltip('关闭'));
    await pumpPresentation(tester);
    expect(container.read(timingPreferencesProvider).threshold, 11);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 640), const Size(768, 1024)]) {
    testWidgets('long stopwatch list has its own scroll at $size', (
      tester,
    ) async {
      await pumpYike(
        tester,
        size: size,
        focus: FocusViewData(
          mode: TimerMode.stopwatch,
          status: TimerStatus.running,
          seconds: 3598,
          laps: List.generate(30, (i) => (i + 1) * 60),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(YikeDial),
          matching: dialDigits('59:58'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('lap-scroll')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('stopwatch-laps-entry')),
      );
      await tester.tap(find.byKey(const ValueKey('stopwatch-laps-entry')));
      await pumpPresentation(tester);
      expect(find.byKey(const ValueKey('lap-panel-list')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('lap-panel-pause')));
      await tester.tap(find.byKey(const ValueKey('lap-panel-pause')));
      await pumpPresentation(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lap-panel-pause')),
          matching: find.text('继续'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
