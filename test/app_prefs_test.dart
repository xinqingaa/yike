import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app_prefs.dart';

void main() {
  test('theme_mode defaults to unset and round-trips light/dark', () {
    final prefs = FakeAppPrefs();
    expect(prefs.readThemeMode(), isNull);
    prefs.writeThemeMode('dark');
    expect(prefs.readThemeMode(), 'dark');
    prefs.writeThemeMode('light');
    expect(prefs.readThemeMode(), 'light');
  });

  test('rejects invalid theme modes without changing preferences', () {
    final prefs = FakeAppPrefs();
    prefs.writeThemeMode('dark');
    expect(() => prefs.writeThemeMode('system'), throwsArgumentError);
    expect(prefs.readThemeMode(), 'dark');
  });

  test('unknown stored theme mode is ignored', () {
    expect(FakeAppPrefs({'theme_mode': 'unknown'}).readThemeMode(), isNull);
  });
}
