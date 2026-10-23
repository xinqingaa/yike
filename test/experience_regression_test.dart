import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/common/widgets/yike/dial.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/theme/ts.dart';

import 'yike_ui_test.dart' show pumpYike, navigateTab;
import 'component_material_test.dart' show shell;

void main() {
  for (final dismissal in ['close', 'barrier', 'back']) {
    testWidgets(
      '$dismissal cancels a mode request without moving the running panel',
      (tester) async {
        var now = DateTime.utc(2026, 10, 16, 12);
        final app = await pumpYike(tester, clock: () => now);
        await tester.tap(find.text('开始专注'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('正计时'));
        await tester.pump();
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
        expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
        await tester.pumpAndSettle();
        expect(find.text('取消'), findsNothing);
        final end = tester.getRect(find.widgetWithText(CommonButton, '结束'));
        final discard = tester.getRect(find.widgetWithText(CommonButton, '放弃'));
        expect(end.left - discard.right, greaterThanOrEqualTo(12));
        expect(end.height, lessThanOrEqualTo(44));
        now = now.add(const Duration(seconds: 20));
        app.read(clockPulseProvider.notifier).refresh();
        await tester.pump();
        switch (dismissal) {
          case 'close':
            await tester.tap(find.byTooltip('关闭'));
          case 'barrier':
            await tester.tapAt(const Offset(12, 100));
          case 'back':
            await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.text('切换计时模式？'), findsNothing);
        expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
        expect(app.read(focusViewProvider).status, TimerStatus.running);
        expect(app.read(focusViewProvider).seconds, 1480);
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final action in ['结束', '放弃']) {
    testWidgets(
      '$action commits exactly one mode transition after confirmation',
      (tester) async {
        final app = await pumpYike(
          tester,
          focus: const FocusViewData(status: TimerStatus.paused, seconds: 1480),
        );
        await tester.tap(find.text('正计时'));
        await tester.tap(find.text('倒计时'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
        expect(find.text('切换计时模式？'), findsOneWidget);
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(app.read(focusViewProvider).mode, TimerMode.stopwatch);
        expect(app.read(focusViewProvider).ready, isTrue);
        expect(
          app.read(focusRecordsProvider),
          hasLength(action == '结束' ? 1 : 0),
        );
        if (action == '结束') {
          expect(app.read(focusRecordsProvider).single.seconds, 20);
        }
        expect(find.text('00:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final accept in [false, true]) {
    testWidgets(
      'short record ${accept ? 'accepts' : 'cancels'} before committing a requested mode',
      (tester) async {
        final app = await pumpYike(
          tester,
          focus: const FocusViewData(
            status: TimerStatus.running,
            seconds: 1495,
          ),
        );
        await tester.tap(find.text('正计时'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('结束'));
        await tester.pumpAndSettle();
        expect(find.text('记录这次短时专注？'), findsOneWidget);
        expect(app.read(focusViewProvider).mode, TimerMode.pomodoro);
        await tester.tap(find.text(accept ? '仍然记录' : '暂不结束'));
        await tester.pumpAndSettle();
        expect(
          app.read(focusViewProvider).mode,
          accept ? TimerMode.stopwatch : TimerMode.pomodoro,
        );
        expect(app.read(focusRecordsProvider), hasLength(accept ? 1 : 0));
        expect(
          app.read(focusViewProvider).status,
          accept ? TimerStatus.ready : TimerStatus.paused,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets(
      '$theme empty review keeps selectable days and only-checkin days visible',
      (tester) async {
        final app = await pumpYike(
          tester,
          theme: theme,
          size: const Size(320, 640),
        );
        await navigateTab(tester, '回顾');
        expect(find.text('这一周还没有记录'), findsOneWidget);
        expect(find.text('去专注'), findsNothing);
        expect(find.text('周一'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('review-day-2026-10-16')),
          findsOneWidget,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('review-day-2026-10-16')),
        );
        final sourceScroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('review-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final sourceOffset = sourceScroll.position.pixels;
        await tester.tap(find.byKey(const ValueKey('review-day-2026-10-16')));
        await tester.pumpAndSettle();
        expect(find.text('这一天没有记录'), findsOneWidget);
        expect(sourceScroll.position.pixels, sourceOffset);
        final dayText = tester.getRect(find.text('10月16日 周五'));
        expect(
          dayText.left,
          closeTo(
            TS.of(tester.element(find.text('10月16日 周五'))).spacing.md,
            .01,
          ),
        );
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        app.read(habitsProvider.notifier).toggle('habit-water', '2026-10-16');
        await tester.pumpAndSettle();
        expect(find.text('这一周还没有记录'), findsNothing);
        expect(find.text('1次'), findsOneWidget);
        expect(find.text('按类型'), findsNothing);
        await tester.ensureVisible(find.text('月'));
        await tester.tap(find.text('月'));
        await tester.pumpAndSettle();
        expect(find.text('1次'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$theme year grid shows readable outlined days near today', (
      tester,
    ) async {
      await pumpYike(tester, theme: theme);
      await navigateTab(tester, '打卡');
      await tester.tap(find.byKey(const ValueKey('habit-detail-habit-water')));
      await tester.pumpAndSettle();
      final cell = find.byKey(const ValueKey('habit-day-2026-10-16'));
      final decoration =
          tester.widget<DecoratedBox>(cell).decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.rectangle);
      expect(decoration.border, isNotNull);
      expect(decoration.color, Colors.transparent);
      expect(tester.getSize(cell).width, greaterThanOrEqualTo(12));
      final viewport = tester.getRect(
        find.byKey(const ValueKey('habit-year-scroll')),
      );
      expect(viewport.contains(tester.getCenter(cell)), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final count in [1, 2, 3]) {
    testWidgets(
      '$count wheel columns keep units adjacent to the selected numbers',
      (tester) async {
        await tester.pumpWidget(
          shell(
            (context) => Center(
              child: SizedBox(
                width: 320,
                child: CommonWheelPicker(
                  visibleRows: 3,
                  columns: [
                    for (var i = 0; i < count; i++)
                      CommonWheelColumn(
                        id: '$i',
                        label: '数值$i',
                        unit: '单位$i',
                        numeric: true,
                        options: [
                          for (var n = 0; n < 20; n++)
                            CommonWheelOption(value: n, label: '$n'),
                        ],
                      ),
                  ],
                  values: List.filled(count, 11),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < count; i++) {
          final number = tester.getRect(find.text('11').at(i));
          final unit = tester.getRect(find.text('单位$i'));
          expect(unit.left - number.right, inInclusiveRange(0, 16));
          expect(unit.center.dy, greaterThan(number.center.dy));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the whole wheel column accepts scrolling beside its readout', (
    tester,
  ) async {
    var selected = 11;
    await tester.pumpWidget(
      shell(
        (context) => Center(
          child: SizedBox(
            width: 320,
            child: CommonWheelPicker(
              visibleRows: 3,
              columns: [
                CommonWheelColumn(
                  id: 'whole',
                  label: '次数',
                  unit: '次',
                  numeric: true,
                  options: [
                    for (var n = 0; n < 20; n++)
                      CommonWheelOption(value: n, label: '$n'),
                  ],
                ),
              ],
              values: const [11],
              onChanged: (value) => selected = value.single as int,
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(CommonWheelPicker));
    await tester.dragFrom(
      Offset(rect.right - 12, rect.center.dy),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    expect(selected, greaterThan(11));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion keeps mode confirmation and theme updates functional',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = await pumpYike(tester);
      await tester.tap(find.text('正计时'));
      await tester.pumpAndSettle();
      expect(app.read(focusViewProvider).mode, TimerMode.stopwatch);
      await tester.tap(find.text('开始计时'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('倒计时'));
      await tester.pumpAndSettle();
      expect(app.read(focusViewProvider).mode, TimerMode.stopwatch);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      app.read(themePackProvider.notifier).select('yike/water');
      await tester.pumpAndSettle();
      expect(app.read(focusViewProvider).status, TimerStatus.running);
      expect(
        find.descendant(
          of: find.byType(YikeDial),
          matching: find.text('00:00'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completed facts remain filled during an archived habit interval',
    (tester) async {
      final app = await pumpYike(tester);
      app.read(habitsProvider.notifier).replace([
        HabitViewData(
          id: 'habit-water',
          name: '喝够 8 杯水',
          created: '2026-10-01',
          archivedOn: '2026-10-14',
          dates: const {'2026-10-14'},
          checkins: {
            '2026-10-14': HabitCheckin(
              id: 'completed-day',
              at: DateTime.utc(2026, 10, 14),
            ),
          },
        ),
      ]);
      await navigateTab(tester, '打卡');
      await tester.tap(find.text('已归档习惯'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('喝够 8 杯水'));
      await tester.pumpAndSettle();
      BoxDecoration decoration(String day) =>
          tester
                  .widget<DecoratedBox>(find.byKey(ValueKey('habit-day-$day')))
                  .decoration
              as BoxDecoration;
      final ts = TS.of(tester.element(find.bySemanticsLabel('最近365天完成 1 次')));
      expect(decoration('2026-10-14').color, ts.colors.primary);
      expect(decoration('2026-10-15').color, ts.colors.surfaceVariant);
      expect(decoration('2026-10-13').color, Colors.transparent);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'theme animation frames keep the dial readout size stable when changing brightness',
    (tester) async {
      final app = await pumpYike(tester, theme: 'water');
      final before = tester.widget<Text>(find.text('25:00')).style!.fontSize!;
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 45));
        expect(tester.widget<Text>(find.text('25:00')).style!.fontSize, before);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
