import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yike/storage/app_prefs.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/theme/app_tokens.dart';
import 'package:yike/theme/ts.dart';

import 'support/fake_app_prefs.dart';

const customPack = AppThemePack(
  id: 'product',
  label: 'Product',
  light: generatedBaseDarkColors,
  dark: generatedBaseLightColors,
  radius: AppRadius(md: 20),
);

void main() {
  testWidgets('adjacent local themes stay independent across rebuilds', (
    tester,
  ) async {
    Widget probe(String label) => Builder(
      builder: (context) {
        final ts = TS.of(context);
        return Text(label, style: ts.textStyle.content);
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: Column(
            children: [
              probe('base-before'),
              Theme(
                data: TS(
                  brightness: Brightness.light,
                  pack: customPack,
                ).toThemeData(),
                child: probe('custom'),
              ),
              probe('base-after'),
            ],
          ),
        ),
      ),
    );
    Color? color(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(color('base-before'), AppThemePack.base.light.onSurface);
    expect(color('custom'), AppThemePack.base.dark.onSurface);
    expect(color('base-after'), AppThemePack.base.light.onSurface);
    await tester.pump();
    expect(color('base-before'), AppThemePack.base.light.onSurface);
  });

  test('theme package selection persists and restores by stable identity', () {
    final prefs = FakeAppPrefs();
    ProviderContainer container() => ProviderContainer(
      overrides: [
        appPrefsProvider.overrideWithValue(prefs),
        themePacksProvider.overrideWithValue([AppThemePack.base, customPack]),
      ],
    );
    final first = container();
    first.read(themePackProvider.notifier).select(customPack.id);
    expect(first.read(themePackProvider).radius.md, 20);
    first.dispose();
    final second = container();
    addTearDown(second.dispose);
    expect(second.read(themePackProvider).id, customPack.id);
    expect(prefs.readString(AppPrefs.themePackKey), customPack.id);
  });

  test('removed package preference recovers to the registered default', () {
    final container = ProviderContainer(
      overrides: [
        appPrefsProvider.overrideWithValue(
          FakeAppPrefs({AppPrefs.themePackKey: 'removed-package'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(themePackProvider).id, AppThemePack.base.id);
    expect(
      () => container.read(themePackProvider.notifier).select('unregistered'),
      throwsStateError,
    );
    expect(container.read(themePackProvider).id, AppThemePack.base.id);
  });
}
