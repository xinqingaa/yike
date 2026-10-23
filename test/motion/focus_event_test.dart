import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/overlay/app_pop.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/router/router.dart';
import 'package:yike/theme/ts.dart';
import '../support/pump_presentation.dart';
import '../yike_ui_test.dart' show pumpYike;

double completionScale(WidgetTester tester) => tester
    .widget<Transform>(
      find.byKey(const ValueKey('focus-completion-motion')).first,
    )
    .transform
    .storage[0];

void main() {
  testWidgets(
    'visible completion plays once; save retry and theme rebuild cannot restart it',
    (tester) async {
      var now = DateTime.utc(2026, 10, 16, 12);
      final app = await pumpYike(tester, clock: () => now);
      final actions = app.read(focusActionsProvider);
      actions.switchMode(TimerMode.countdown);
      actions.selectCountdown(1);
      await pumpPresentation(tester);
      actions.start();
      await tester.pump();
      now = now.add(const Duration(seconds: 1));
      app.read(clockPulseProvider.notifier).refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(completionScale(tester), greaterThan(1));
      expect(app.read(focusRecordsProvider), hasLength(1));
      app.read(localDataProvider.notifier).retry();
      app.read(themePackProvider.notifier).select('yike/water');
      await pumpPresentation(tester);
      expect(completionScale(tester), 1);
      app.read(localDataProvider.notifier).retry();
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(completionScale(tester), 1);
      expect(app.read(focusRecordsProvider), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('coalesced hidden completion and return cannot create feedback', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 16, 12);
    final app = await pumpYike(tester, clock: () => now);
    final actions = app.read(focusActionsProvider);
    actions.switchMode(TimerMode.countdown);
    actions.selectCountdown(1);
    await pumpPresentation(tester);
    actions.start();
    await tester.pump();
    app.read(rootTabProvider.notifier).set(1);
    now = now.add(const Duration(seconds: 1));
    app.read(clockPulseProvider.notifier).refresh();
    app.read(rootTabProvider.notifier).set(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(completionScale(tester), 1);
    expect(app.read(focusRecordsProvider), hasLength(1));
  });

  testWidgets('resume calibration skips an overdue background completion', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 16, 12);
    final app = await pumpYike(tester, clock: () => now);
    final actions = app.read(focusActionsProvider);
    actions.switchMode(TimerMode.countdown);
    actions.selectCountdown(1);
    await pumpPresentation(tester);
    actions.start();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    // No pulse or frame occurs while the process is suspended.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(completionScale(tester), 1);
    expect(app.read(focusRecordsProvider), hasLength(1));
  });

  for (final hidden in ['tab', 'route', 'modal', 'background']) {
    testWidgets('completion behind $hidden is not replayed on return', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 16, 12);
      final app = await pumpYike(tester, clock: () => now);
      final actions = app.read(focusActionsProvider);
      actions.switchMode(TimerMode.countdown);
      actions.selectCountdown(1);
      await pumpPresentation(tester);
      actions.start();
      await tester.pump();
      final sheet = AppSheet<void>();
      if (hidden == 'tab') app.read(rootTabProvider.notifier).set(1);
      if (hidden == 'route') {
        appNavigatorKey.currentState!.pushNamed(AppRoutes.settings);
      }
      if (hidden == 'modal') {
        unawaited(sheet.show(title: '操作', child: const Text('当前操作')));
      }
      if (hidden == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }
      await pumpPresentation(tester);
      now = now.add(const Duration(seconds: 1));
      app.read(clockPulseProvider.notifier).refresh();
      await pumpPresentation(tester);
      expect(app.read(focusRecordsProvider), hasLength(1));
      if (hidden == 'tab') app.read(rootTabProvider.notifier).set(0);
      if (hidden == 'route') appNavigatorKey.currentState!.pop();
      if (hidden == 'modal') unawaited(sheet.dismiss());
      if (hidden == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      // The selected panel may still be travelling into view.
      await pumpPresentation(tester);
      expect(completionScale(tester), 1);
      expect(app.read(focusRecordsProvider), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reduced motion interrupts completion and root navigation immediately',
    (tester) async {
      var now = DateTime.utc(2026, 10, 16, 12);
      final app = await pumpYike(tester, clock: () => now);
      final actions = app.read(focusActionsProvider);
      actions.switchMode(TimerMode.countdown);
      actions.selectCountdown(1);
      await pumpPresentation(tester);
      actions.start();
      await tester.pump();
      now = now.add(const Duration(seconds: 1));
      app.read(clockPulseProvider.notifier).refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(completionScale(tester), greaterThan(1));
      app.read(rootTabProvider.notifier).set(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final selection = tester
          .widget<CommonBottomNav>(find.byType(CommonBottomNav))
          .selection!;
      expect(selection.value, inExclusiveRange(0, 1));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<CommonBottomNav>(find.byType(CommonBottomNav))
            .selection!
            .value,
        1,
      );
      app.read(rootTabProvider.notifier).set(0);
      await tester.pump();
      await tester.pump();
      expect(completionScale(tester), 1);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(completionScale(tester), 1);
      expect(tester.takeException(), isNull);
    },
  );
}
