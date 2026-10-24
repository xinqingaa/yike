// Temporary stage 1 lap overflow regression; remove after user acceptance.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/widgets/lap_list.dart';
import 'support/pump_presentation.dart';
import 'yike_ui_test.dart' show pumpYike;

void main() {
  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        '$theme lap additions fit Xiaomi viewport at text scale $scale',
        (tester) async {
          var now = DateTime(2026, 10, 24, 12);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final app = await pumpYike(
            tester,
            theme: theme,
            size: const Size(375.4, 817.2),
            clock: () => now,
          );
          final actions = app.read(focusActionsProvider);
          actions.switchMode(TimerMode.stopwatch);
          actions.start();
          await pumpPresentation(tester);
          for (var i = 1; i <= 15; i++) {
            now = now.add(Duration(seconds: i == 15 ? 3600 : 2));
            actions.lap();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 60));
            expect(tester.takeException(), isNull);
          }
          actions.pause();
          await pumpPresentation(tester);
          await tester.drag(
            find.byKey(const ValueKey('lap-scroll')),
            const Offset(0, -600),
          );
          await pumpPresentation(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(LapList), findsOneWidget);
        },
      );
    }
  }
}
