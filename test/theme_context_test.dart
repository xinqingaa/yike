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
    expect(prefs.read(AppPrefs.themePack), customPack.id);
  });

  test('removed package preference recovers to the registered default', () {
    final container = ProviderContainer(
      overrides: [
        appPrefsProvider.overrideWithValue(
          FakeAppPrefs({PrefsKey.themePack.storageKey: 'removed-package'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(themePackProvider).id, 'yike/mechanical');
    expect(
      () => container.read(themePackProvider.notifier).select('unregistered'),
      throwsStateError,
    );
    expect(container.read(themePackProvider).id, 'yike/mechanical');
  });
  test(
    'theme geometry and shadows remain continuous across brightness midpoint',
    () {
      final pack = generatedThemePacks.firstWhere(
        (p) => p.id == 'yike/sundial',
      );
      final light = TS(brightness: Brightness.light, pack: pack);
      final dark = TS(brightness: Brightness.dark, pack: pack);
      final before = light.lerp(dark, .49), after = light.lerp(dark, .51);
      expect(
        (before.effect.artworkShadow.first.blurRadius -
                after.effect.artworkShadow.first.blurRadius)
            .abs(),
        lessThan(1),
      );
      expect(
        (before.opacity.translucent - after.opacity.translucent).abs(),
        lessThan(.01),
      );
      final water = TS(
        brightness: Brightness.light,
        pack: generatedThemePacks.firstWhere((p) => p.id == 'yike/water'),
      );
      final blend = light.lerp(water, .5);
      expect(
        blend.sizing.plot,
        closeTo((light.sizing.plot + water.sizing.plot) / 2, .001),
      );
      expect(blend.artworkThemes.values, everyElement(.5));
    },
  );
}
