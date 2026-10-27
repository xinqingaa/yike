import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'package:yike/theme/ts.dart';

import 'support/fake_app_prefs.dart';
import 'support/pump_presentation.dart';
import 'yike_ui_test.dart' show pumpYike;

void main() {
  testWidgets('single glass introduction selects a theme and stays complete', (
    tester,
  ) async {
    final prefs = FakeAppPrefs();
    var app = await pumpYike(tester, preferences: prefs, freshInstall: true);
    expect(find.text('找到适合你的节奏'), findsOneWidget);
    expect(find.bySemanticsLabel('第1步，共2步'), findsNothing);
    expect(find.text('从零开始，记录投入的时间'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-glass')), findsOneWidget);
    expect(find.text('选择你的表盘'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('theme-yike/water')));
    await tester.tap(find.byKey(const ValueKey('theme-yike/water')));
    await pumpPresentation(tester);
    expect(app.read(themePackProvider).id, 'yike/water');
    await tester.tap(find.text('开始使用'));
    await pumpPresentation(tester);
    expect(prefs.read(localDataPrefs)!.onboardingComplete, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    app = await pumpYike(tester, preferences: prefs, freshInstall: true);
    expect(find.text('认识一刻'), findsNothing);
    expect(app.read(themePackProvider).id, 'yike/water');
  });

  testWidgets(
    'skip persists, reset does not reopen and settings offers replay',
    (tester) async {
      final prefs = FakeAppPrefs();
      final app = await pumpYike(
        tester,
        preferences: prefs,
        freshInstall: true,
      );
      await tester.tap(find.byTooltip('跳过'));
      await pumpPresentation(tester);
      expect(prefs.read(localDataPrefs)!.onboardingComplete, isTrue);
      app.read(localDataProvider.notifier).reset();
      await pumpPresentation(tester);
      expect(find.text('认识一刻'), findsNothing);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(CommonPrimaryTabs),
          matching: find.text('通用'),
        ),
      );
      await pumpPresentation(tester);
      await tester.tap(find.text('新手引导'));
      await pumpPresentation(tester);
      expect(find.text('找到适合你的节奏'), findsOneWidget);
    },
  );

  testWidgets('narrow large text can navigate to themes and finish', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final prefs = FakeAppPrefs();
    await pumpYike(
      tester,
      preferences: prefs,
      freshInstall: true,
      size: const Size(320, 640),
    );
    expect(find.text('选择你的表盘'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('开始使用'));
    await pumpPresentation(tester);
    expect(prefs.read(localDataPrefs)!.onboardingComplete, isTrue);
  });

  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final mode in ['light', 'dark']) {
      testWidgets('introduction renders in $theme $mode', (tester) async {
        final prefs = FakeAppPrefs({
          'theme_pack': 'yike/$theme',
          'theme_mode': mode,
        });
        await pumpYike(tester, preferences: prefs, freshInstall: true);
        expect(find.text('找到适合你的节奏'), findsOneWidget);
        expect(find.text('选择你的表盘'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  test(
    'existing snapshot without introduction field is treated as completed',
    () {
      final old = YikeData.initial(DateTime(2026)).toJson()
        ..remove('onboardingComplete');
      expect(YikeData.fromJson(old).onboardingComplete, isTrue);
    },
  );
}
