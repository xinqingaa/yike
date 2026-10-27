import 'support/dial_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/features/focus/focus.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('bootstrap enters the first-use focus screen', (tester) async {
    await pumpPbApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('开始专注'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FocusPage),
        matching: dialDigits('25:00'),
      ),
      findsOneWidget,
    );
    expect(find.text('等待 PBWork Handoff'), findsNothing);
  });
  testWidgets('turning reduced motion off after startup keeps the home route', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await pumpPbApp(tester);
    await tester.pumpAndSettle();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pumpAndSettle();
    expect(find.text('开始专注'), findsOneWidget);
    expect(find.text('打开，就开始这一刻'), findsNothing);
  });
}
