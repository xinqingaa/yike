import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/review/widgets/period_controls.dart';

import 'support/pump_presentation.dart';
import 'yike_ui_test.dart' show pumpYike, navigateTab;

void main() {
  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final large in [false, true]) {
      testWidgets('$theme review selection is centered, large=$large', (
        tester,
      ) async {
        if (large) {
          tester.platformDispatcher.textScaleFactorTestValue = 3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        await pumpYike(
          tester,
          theme: theme,
          size: large ? const Size(320, 640) : const Size(390, 844),
        );
        await navigateTab(tester, '回顾');
        final controls = find.byType(ReviewPeriodControls);
        final nativeTabs = find.descendant(
          of: controls,
          matching: find.byType(Tab),
        );
        for (final selected in ['周', '月']) {
          await tester.tap(
            find.descendant(of: controls, matching: find.text(selected)),
          );
          await pumpPresentation(tester);
          for (var i = 0; i < 2; i++) {
            final slot = tester.getRect(nativeTabs.at(i));
            final text = find.descendant(
              of: controls,
              matching: find.text(['周', '月'][i]),
            );
            final label = tester.getRect(text);
            expect(label.center.dx, closeTo(slot.center.dx, .1));
            expect(label.center.dy, closeTo(slot.center.dy, .1));
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: text, matching: find.byType(RichText)),
            );
            final box = paragraph
                .getBoxesForSelection(
                  const TextSelection(baseOffset: 0, extentOffset: 1),
                )
                .single;
            final paintedCenter = paragraph.localToGlobal(
              Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2),
            );
            expect(paintedCenter.dx, closeTo(slot.center.dx, .5));
            expect(paintedCenter.dy, closeTo(slot.center.dy, .5));
          }
          final picker = find.byKey(const ValueKey('review-period-picker'));
          expect(
            find.descendant(of: picker, matching: find.byType(CommonIcon)),
            findsNothing,
          );
          expect(
            tester.getRect(picker).center.dx,
            closeTo(tester.getRect(controls).center.dx, .1),
          );
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
    'date title stays centered and opens week and month pickers without an arrow',
    (tester) async {
      await pumpYike(tester);
      await navigateTab(tester, '回顾');
      final controls = find.byType(ReviewPeriodControls);
      for (final month in [false, true]) {
        if (month) {
          await tester.tap(
            find.descendant(of: controls, matching: find.text('月')),
          );
          await pumpPresentation(tester);
        }
        final picker = find.byKey(const ValueKey('review-period-picker'));
        final title = find.descendant(of: picker, matching: find.byType(Text));
        expect(
          tester.getCenter(title).dx,
          closeTo(tester.getCenter(picker).dx, .1),
        );
        expect(
          find.descendant(of: picker, matching: find.byType(CommonIcon)),
          findsNothing,
        );
        await tester.tap(picker);
        await pumpPresentation(tester);
        expect(find.text('2026年'), findsOneWidget);
        await tester.tap(find.byTooltip('关闭'));
        await pumpPresentation(tester);
        expect(find.byType(ReviewPeriodControls), findsOneWidget);
      }
    },
  );
}
