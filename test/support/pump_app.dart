import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yike/app/app.dart';
import 'package:yike/storage/providers.dart';

import 'fake_app_prefs.dart';

Future<void> pumpPbApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appPrefsProvider.overrideWithValue(FakeAppPrefs(prefs))],
      child: const PbApp(),
    ),
  );
}
