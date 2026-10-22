import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/app/startup.dart';
import 'package:yike/app/app.dart';
import 'package:yike/router/router.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/storage/app_prefs.dart';
import 'support/fake_app_prefs.dart';

void main() {
  testWidgets('pending preparation fills the screen and enters automatically', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ready = Completer<AppPrefs>();
    var calls = 0;
    await tester.pumpWidget(
      AppStartup(
        openPreferences: () {
          calls++;
          return ready.future;
        },
      ),
    );
    expect(tester.getSize(find.byType(CommonLaunchScreen)).width, 390);
    expect(find.text('开始'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(CommonLaunchScreen), findsOneWidget);
    expect(calls, 1);
    ready.complete(FakeAppPrefs());
    await tester.pumpAndSettle();
    expect(find.byType(CommonLaunchScreen), findsNothing);
    expect(find.byType(PbApp), findsOneWidget);
    expect(appNavigatorKey.currentState!.canPop(), isFalse);
    expect(calls, 1);
  });

  testWidgets(
    'preparation failures retry rather than leave a permanent splash',
    (tester) async {
      var calls = 0;
      final retryReady = Completer<AppPrefs>();
      await tester.pumpWidget(
        AppStartup(
          openPreferences: () async {
            if (++calls == 1) throw StateError('storage unavailable');
            return retryReady.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本机存储暂不可用，请重试'), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(find.byType(CommonLaunchScreen), findsOneWidget);
      expect(find.text('本机存储暂不可用，请重试'), findsNothing);
      retryReady.complete(FakeAppPrefs());
      await tester.pumpAndSettle();
      expect(find.byType(PbApp), findsOneWidget);
      expect(calls, 2);
    },
  );
  testWidgets(
    'damaged native storage stops startup without creating defaults',
    (tester) async {
      await tester.pumpWidget(
        AppStartup(
          openPreferences: () async {
            throw const PrefsOpenException(PrefsOpenFailure.damaged);
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本机存储文件损坏，原文件已保留，请检查后重试'), findsOneWidget);
      expect(find.byType(PbApp), findsNothing);
    },
  );
}
