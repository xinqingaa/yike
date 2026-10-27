import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/overlay/app_pop.dart';
import 'package:yike/common/overlay/popup_activity.dart';
import 'package:yike/router/router.dart';

import 'support/pump_presentation.dart';
import 'yike_ui_test.dart' show pumpYike;

void main() {
  var exits = 0;
  setUp(() {
    exits = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (var tab = 0; tab < 3; tab++) {
    testWidgets('Android tab $tab requires two root backs', (tester) async {
      final app = await pumpYike(tester);
      app.read(rootTabProvider.notifier).set(tab);
      await pumpPresentation(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits, 0);
      expect(find.text('再按一次返回键退出应用'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(exits, 1);
    });
  }

  testWidgets('timeout, tab changes and background clear the exit window', (
    tester,
  ) async {
    final app = await pumpYike(tester);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 0);
    app.read(rootTabProvider.notifier).set(1);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    expect(exits, 1);
  });

  testWidgets('custom modal back closes only the introduction', (tester) async {
    final app = await pumpYike(tester, freshInstall: true);
    expect(app.read(popupActivityProvider), 1);
    await tester.binding.handlePopRoute();
    await pumpPresentation(tester);
    expect(find.text('认识一刻'), findsNothing);
    expect(find.text('再按一次返回键退出应用'), findsNothing);
    expect(app.read(popupActivityProvider), 0);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    expect(exits, 1);
  });

  testWidgets('child routes and nested popups take priority over root exit', (
    tester,
  ) async {
    await pumpYike(tester);
    appNavigatorKey.currentState!.pushNamed(AppRoutes.settings);
    await pumpPresentation(tester);
    final sheet = AppSheet<void>();
    sheet.show(child: const Text('测试面板'));
    await pumpPresentation(tester);
    await tester.binding.handlePopRoute();
    await pumpPresentation(tester);
    expect(find.text('测试面板'), findsNothing);
    expect(appNavigatorKey.currentState!.canPop(), isTrue);
    expect(find.text('再按一次返回键退出应用'), findsNothing);
    await tester.binding.handlePopRoute();
    await pumpPresentation(tester);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
    expect(find.text('再按一次返回键退出应用'), findsNothing);
    expect(exits, 0);
  });

  testWidgets('iOS keeps child route swipe back without exit confirmation', (
    tester,
  ) async {
    await pumpYike(tester);
    appNavigatorKey.currentState!.pushNamed(AppRoutes.settings);
    await pumpPresentation(tester);
    await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
    await pumpPresentation(tester);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
    expect(find.text('再按一次返回键退出应用'), findsNothing);
    expect(exits, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
