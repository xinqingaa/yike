import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('bootstrap renders the generated target shell', (tester) async {
    await pumpPbApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Yike'), findsOneWidget);
    expect(find.text('等待 PBWork Handoff'), findsOneWidget);
  });
}
