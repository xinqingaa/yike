import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/widgets/countdown_choices.dart';
import 'package:yike/features/focus/widgets/lap_list.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/review/review.dart';
import 'package:yike/theme/ts.dart';

import 'component_material_test.dart' show shell;
import 'yike_ui_test.dart' show pumpYike, navigateTab;

void main() {
  for (final count in [1, 2, 3]) {
    testWidgets('$count wheels center digits independently of short units', (
      tester,
    ) async {
      for (final scale in [1.0, 1.6]) {
        for (final value in [0, 9, 10, 59]) {
          await tester.pumpWidget(
            shell(
              (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: SizedBox(
                    width: 288,
                    child: CommonWheelPicker(
                      columns: [
                        for (var i = 0; i < count; i++)
                          CommonWheelColumn(
                            id: '$i',
                            label: '时长$i',
                            unit: ['时', '分', '秒'][i],
                            numeric: true,
                            options: [
                              for (var n = 0; n < 60; n++)
                                CommonWheelOption(
                                  value: n,
                                  label: '$n'.padLeft(2, '0'),
                                ),
                            ],
                          ),
                      ],
                      values: List.filled(count, value),
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (var i = 0; i < count; i++) {
            final column = tester.getRect(
              find.byKey(ValueKey('wheel-column-$i')),
            );
            final number = tester.getRect(
              find.byKey(ValueKey('wheel-number-$i')),
            );
            final unit = tester.getRect(find.byKey(ValueKey('wheel-unit-$i')));
            expect(number.center.dx, closeTo(column.center.dx, .01));
            expect(unit.left - number.right, inInclusiveRange(0, 8));
            expect(unit.right, lessThanOrEqualTo(column.right));
          }
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets(
    'flow progress defaults off and only reserves space when configured',
    (tester) async {
      Future<void> pump(CommonFlowSheetProgress? progress) => tester.pumpWidget(
        shell(
          (_) => SizedBox(
            height: 400,
            child: CommonFlowSheetContent(
              progress: progress,
              body: const Text('正文'),
              actions: [CommonButton(label: '保存', onPressed: () {})],
            ),
          ),
        ),
      );
      await pump(null);
      final without = tester.getSize(find.byType(SingleChildScrollView)).height;
      expect(find.bySemanticsLabel('第1步，共2步'), findsNothing);
      await pump(const CommonFlowSheetProgress(step: 0, total: 2));
      expect(find.bySemanticsLabel('第1步，共2步'), findsOneWidget);
      final withProgress = tester
          .getSize(find.byType(SingleChildScrollView))
          .height;
      expect(without, greaterThan(withProgress));
      await pump(null);
      expect(
        tester.getSize(find.byType(SingleChildScrollView)).height,
        without,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [0, 1, 3, 4]) {
    testWidgets(
      '$count countdown presets use equal columns and a full custom row',
      (tester) async {
        final presets = [180, 300, 86399, 3600].take(count).toList();
        int? selected;
        var custom = 0;
        await tester.pumpWidget(
          shell(
            (context) => Center(
              child: SizedBox(
                width: 272,
                child: CountdownChoices(
                  availableWidth: 272,
                  presets: presets,
                  value: 86398,
                  onSelected: (value) => selected = value,
                  onCustom: () => custom++,
                ),
              ),
            ),
          ),
        );
        final customRect = tester.getRect(
          find.byKey(const ValueKey('countdown-custom')),
        );
        expect(customRect.width, 272);
        for (var i = 0; i < presets.length; i++) {
          final rect = tester.getRect(
            find.byKey(ValueKey('countdown-preset-${presets[i]}')),
          );
          expect(rect.width, (272 - 8) / 2);
          expect(
            rect.height,
            tester
                .getSize(
                  find.byKey(ValueKey('countdown-preset-${presets.first}')),
                )
                .height,
          );
          expect(rect.bottom, lessThan(customRect.top));
          if (i.isOdd) {
            expect(
              rect.top,
              tester
                  .getTopLeft(
                    find.byKey(ValueKey('countdown-preset-${presets[i - 1]}')),
                  )
                  .dy,
            );
          }
        }
        if (presets.isNotEmpty) {
          await tester.tap(
            find.byKey(ValueKey('countdown-preset-${presets.first}')),
          );
          expect(selected, presets.first);
        }
        await tester.tap(find.byKey(const ValueKey('countdown-custom')));
        expect(custom, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('countdown choices and custom cancellation never start a timer', (
    tester,
  ) async {
    final app = await pumpYike(tester, size: const Size(320, 640));
    await tester.tap(find.text('倒计时'));
    await tester.pumpAndSettle();
    final preset = find.byKey(const ValueKey('countdown-preset-600'));
    await tester.ensureVisible(preset);
    await tester.tap(preset);
    await tester.pumpAndSettle();
    expect(app.read(focusViewProvider).target, 600);
    expect(app.read(focusViewProvider).ready, isTrue);
    final custom = find.byKey(const ValueKey('countdown-custom'));
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect(find.text('时'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);
    expect(find.text('秒'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(app.read(focusViewProvider).target, 600);
    expect(app.read(focusViewProvider).ready, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'lap table aligns time edges and baselines across unequal durations',
    (tester) async {
      await tester.pumpWidget(
        shell(
          (_) => Center(
            child: SizedBox(
              width: 272,
              child: LapList(
                compact: false,
                value: FocusViewData(
                  mode: TimerMode.stopwatch,
                  status: TimerStatus.paused,
                  seconds: 4030,
                  laps: [for (var i = 1; i < 13; i++) i * 300],
                ),
              ),
            ),
          ),
        ),
      );
      final lap = find.byKey(const ValueKey('lap-duration-13'));
      final total = find.byKey(const ValueKey('lap-total-13'));
      final previous = find.byKey(const ValueKey('lap-total-12'));
      expect(tester.getRect(total).right, tester.getRect(previous).right);
      double baseline(Finder finder) {
        final box = tester.renderObject<RenderBox>(finder);
        return box
            .localToGlobal(
              Offset(
                0,
                box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!,
              ),
            )
            .dy;
      }

      expect(baseline(lap), closeTo(baseline(total), .01));
      expect(
        baseline(find.byKey(const ValueKey('lap-label-13'))),
        closeTo(baseline(total), .01),
      );
      expect(find.text('暂停 · 13'), findsOneWidget);
      final viewport = find.byType(CommonScrollableDataList);
      final top = tester.getTopLeft(viewport);
      await tester.drag(viewport, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(viewport), top);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets(
      '$theme countdown and stopwatch actions fit the phone default',
      (tester) async {
        tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.resetPadding);
        await pumpYike(tester, theme: theme);
        await tester.tap(find.text('倒计时'));
        await tester.pumpAndSettle();
        final primary = find.byKey(const ValueKey('focus-primary')).last;
        expect(
          tester.getRect(primary).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(CommonBottomNav)).top),
        );
        await tester.tap(find.text('正计时'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('开始计时'));
        await tester.pumpAndSettle();
        final cancel = find.widgetWithText(CommonButton, '取消计时');
        expect(
          tester.getRect(cancel).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(CommonBottomNav)).top),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$theme day feedback uses the theme above artwork and clears on release',
      (tester) async {
        await pumpYike(tester, theme: theme);
        await navigateTab(tester, '回顾');
        final day = find.byKey(const ValueKey('review-day-2026-10-16'));
        final ts = TS.of(tester.element(day));
        final animation = find
            .descendant(of: day, matching: find.byType(AnimatedContainer))
            .first;
        ShapeDecoration feedback() =>
            tester.widget<AnimatedContainer>(animation).foregroundDecoration!
                as ShapeDecoration;
        expect(feedback().color!.a, 0);
        final gesture = await tester.startGesture(tester.getCenter(day));
        await tester.pumpAndSettle();
        expect(
          feedback().color,
          ts.colors.primary.withValues(alpha: ts.opacity.pressed),
        );
        expect(feedback().shape, isA<RoundedRectangleBorder>());
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('每日记录'), findsOneWidget);
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(feedback().color!.a, 0);
        await tester.tap(day);
        await tester.pumpAndSettle();
        expect(find.text('每日记录'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'review dates have action semantics and retain only browsing context',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await pumpYike(tester);
      await navigateTab(tester, '回顾');
      await tester.tap(find.text('月'));
      await tester.pumpAndSettle();
      final day = find.bySemanticsLabel('2026-10-16');
      expect(
        tester.getSemantics(day).flagsCollection.isSelected,
        Tristate.none,
      );
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('day-previous')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(app.read(reviewSelectionProvider).lastViewedDate, '2026-10-15');
      expect(
        tester.getSemantics(day).flagsCollection.isSelected,
        Tristate.none,
      );
      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      expect(app.read(reviewSelectionProvider).anchor, DateTime(2026, 10, 15));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'daily detail aligns records and keeps navigation fixed while scrolling',
    (tester) async {
      final app = await pumpYike(
        tester,
        size: const Size(320, 640),
        records: [
          for (var i = 0; i < 16; i++)
            FocusRecordView(
              date: '2026-10-16',
              time: '${8 + i ~/ 4}:${(i * 3 % 60).toString().padLeft(2, '0')}',
              seconds: [5.5, 3601, 86399][i % 3],
              mode: TimerMode.values[i % 3],
            ),
        ],
      );
      app.read(habitsProvider.notifier).toggle('habit-water', '2026-10-16');
      await navigateTab(tester, '回顾');
      final day = find.byKey(const ValueKey('review-day-2026-10-16'));
      await tester.ensureVisible(day);
      await tester.tap(day);
      await tester.pumpAndSettle();
      final time = find.byKey(const ValueKey('day-record-time-0'));
      final mode = find.byKey(const ValueKey('day-record-mode-0'));
      double baseline(Finder finder) {
        final box = tester.renderObject<RenderBox>(finder);
        return box
            .localToGlobal(
              Offset(
                0,
                box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!,
              ),
            )
            .dy;
      }

      expect(baseline(time), closeTo(baseline(mode), .01));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('day-record-duration-0')))
            .right,
        tester
            .getRect(find.byKey(const ValueKey('day-record-duration-1')))
            .right,
      );
      final next = find.byKey(const ValueKey('day-next'));
      final before = tester.getRect(next);
      expect(before.height, greaterThanOrEqualTo(44));
      await tester.drag(
        find.byType(CommonDataList).last,
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(next), before);
      expect(find.text('喝够 8 杯水'), findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        find.text('10月16日 周五'),
        findsNothing,
      ); // still scrolled; future navigation is disabled
      expect(app.read(reviewSelectionProvider).lastViewedDate, '2026-10-16');
      expect(tester.takeException(), isNull);
    },
  );
}
