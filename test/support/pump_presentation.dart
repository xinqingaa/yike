import 'package:flutter_test/flutter_test.dart';

/// Advance a bounded presentation interval while timer dials may keep ticking.
/// The injected business clock remains controlled by the individual scenario.
Future<void> pumpPresentation(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}
