import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('bootstrap enters the first-use focus screen', (tester) async {
    await pumpPbApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('开始专注'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('等待 PBWork Handoff'), findsNothing);
  });
}
