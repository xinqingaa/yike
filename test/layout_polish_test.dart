import 'support/pump_presentation.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/features/focus/widgets/countdown_choices.dart';
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
          await pumpPresentation(tester);
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
    testWidgets('$count countdown presets and edit share one row', (
      tester,
    ) async {
      final presets = [180, 300, 3599, 360].take(count).toList();
      int? selected;
      var edits = 0;
      await tester.pumpWidget(
        shell(
          (context) => Center(
            child: SizedBox(
              width: 272,
              child: CountdownChoices(
                availableWidth: 272,
                presets: presets,
                selectedIndex: null,
                onSelected: (value) => selected = value,
                onEdit: () => edits++,
              ),
            ),
          ),
        ),
      );
      final edit = find.byKey(const ValueKey('countdown-edit'));
      final editRect = tester.getRect(edit);
      expect(
        editRect.right,
        lessThanOrEqualTo(tester.getRect(find.byType(CountdownChoices)).right),
      );
      for (final seconds in presets) {
        final rect = tester.getRect(
          find.byKey(ValueKey('countdown-preset-$seconds')),
        );
        expect(rect.center.dy, closeTo(editRect.center.dy, 1));
      }
      if (presets.isNotEmpty) {
        await tester.tap(
          find.byKey(ValueKey('countdown-preset-${presets.first}')),
        );
        expect(selected, presets.first);
      }
      await tester.tap(edit);
      expect(edits, 1);
      expect(find.text('自定义'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'countdown preset editor cancellation preserves the pending target',
    (tester) async {
      final app = await pumpYike(tester, size: const Size(320, 640));
      await tester.tap(find.text('倒计时'));
      await pumpPresentation(tester);
      final preset = find.byKey(const ValueKey('countdown-preset-600'));
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await pumpPresentation(tester);
      expect(app.read(focusViewProvider).target, 600);
      expect(app.read(focusViewProvider).ready, isTrue);
      final edit = find.byKey(const ValueKey('countdown-edit'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await pumpPresentation(tester);
      expect(find.text('常用倒计时'), findsWidgets);
      expect(find.byType(YikeSettingsPage), findsOneWidget);
      await tester.tap(find.text('常用 1'));
      await pumpPresentation(tester);
      expect(find.text('清空此项'), findsNothing);
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
      expect(find.byType(YikeSettingsPage), findsOneWidget);
      expect(find.text('试听提示音'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await pumpPresentation(tester);
      expect(find.byType(YikeSettingsPage), findsNothing);
      expect(app.read(focusViewProvider).target, 600);
      expect(app.read(focusViewProvider).ready, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lap table aligns time edges and baselines across unequal durations',
    (tester) async {
      await pumpYike(
        tester,
        focus: FocusViewData(
          mode: TimerMode.stopwatch,
          status: TimerStatus.paused,
          seconds: 3598,
          laps: [for (var i = 1; i <= 12; i++) i * 240],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('stopwatch-laps-entry')));
      await pumpPresentation(tester);
      final lap = find.byKey(const ValueKey('lap-duration-12'));
      final total = find.byKey(const ValueKey('lap-total-12'));
      final previous = find.byKey(const ValueKey('lap-total-11'));
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
        baseline(find.byKey(const ValueKey('lap-label-12'))),
        closeTo(baseline(total), .01),
      );
      expect(find.text('已暂停'), findsWidgets);
      final viewport = find.byKey(const ValueKey('lap-panel-list'));
      final top = tester.getTopLeft(viewport);
      await tester.drag(viewport, const Offset(0, -800));
      await pumpPresentation(tester);
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
        await pumpPresentation(tester);
        final primary = find.byKey(const ValueKey('focus-primary')).last;
        expect(
          tester.getRect(primary).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(CommonBottomNav)).top),
        );
        await tester.tap(find.text('正计时'));
        await pumpPresentation(tester);
        await tester.tap(find.text('开始计时'));
        await pumpPresentation(tester);
        expect(find.widgetWithText(CommonButton, '取消计时'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('stopwatch-laps-entry')));
        await pumpPresentation(tester);
        final cancel = find.widgetWithText(CommonButton, '取消计时').last;
        expect(
          tester.getRect(cancel).bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height - 34),
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
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump();
        expect(
          feedback().color,
          ts.colors.primary.withValues(alpha: ts.opacity.pressed),
        );
        expect(feedback().shape, isA<RoundedRectangleBorder>());
        await gesture.up();
        await pumpPresentation(tester);
        await tester.ensureVisible(find.text('查看当日记录'));
        await tester.tap(find.text('查看当日记录'));
        await pumpPresentation(tester);
        expect(find.text('每日记录'), findsOneWidget);
        await tester.tap(find.byTooltip('关闭'));
        await pumpPresentation(tester);
        expect(feedback().color!.a, 0);
        await tester.tap(day);
        await pumpPresentation(tester);
        await tester.ensureVisible(find.text('查看当日记录'));
        await tester.tap(find.text('查看当日记录'));
        await pumpPresentation(tester);
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
      await pumpPresentation(tester);
      final day = find.bySemanticsLabel('2026-10-16');
      expect(
        tester.getSemantics(day).flagsCollection.isSelected,
        Tristate.none,
      );
      await tester.tap(day);
      await pumpPresentation(tester);
      await tester.ensureVisible(find.text('查看当日记录'));
      await tester.tap(find.text('查看当日记录'));
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('day-previous')));
      await pumpPresentation(tester);
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
      expect(app.read(reviewSelectionProvider).lastViewedDate, '2026-10-15');
      expect(
        tester.getSemantics(day).flagsCollection.isSelected,
        Tristate.none,
      );
      await tester.tap(find.text('周'));
      await pumpPresentation(tester);
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
      await pumpPresentation(tester);
      await tester.ensureVisible(find.text('查看当日记录'));
      await tester.tap(find.text('查看当日记录'));
      await pumpPresentation(tester);
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
      await pumpPresentation(tester);
      expect(tester.getRect(next), before);
      expect(find.text('喝够 8 杯水'), findsOneWidget);
      await tester.tap(next);
      await pumpPresentation(tester);
      expect(
        find.text('10月16日 周五'),
        findsNothing,
      ); // still scrolled; future navigation is disabled
      expect(app.read(reviewSelectionProvider).lastViewedDate, '2026-10-16');
      expect(tester.takeException(), isNull);
    },
  );
}
