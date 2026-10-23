import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/overlay/app_pop.dart';
import 'package:yike/common/overlay/popup_activity.dart';
import 'package:yike/common/widgets/yike/dial.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/router/router.dart';
import 'package:yike/storage/app_prefs.dart';
import 'package:yike/storage/preference_writer.dart';
import 'package:yike/theme/ts.dart';
import '../features/local_data/local_data_test.dart' show FaultPrefs;
import '../support/pump_presentation.dart';
import '../yike_ui_test.dart' show pumpYike, navigateTab;

class SplitFaultPrefs extends FaultPrefs {
  bool failSnapshot = false, failPreferences = false;
  @override
  void writeRaw(PrefsKey key, String value) {
    if (key == PrefsKey.snapshot ? failSnapshot : failPreferences) {
      throw StateError('disk full');
    }
    super.writeRaw(key, value);
  }
}

void main() {
  testWidgets(
    'narrow large-text reduced status is readable and reset removes it',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      final disk = SplitFaultPrefs();
      final app = await pumpYike(
        tester,
        preferences: disk,
        size: const Size(320, 640),
      );
      disk.failPreferences = true;
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await pumpPresentation(tester);
      final status = find.byKey(const ValueKey('unsaved-status'));
      expect(tester.getRect(status).width, lessThanOrEqualTo(320));
      expect(find.text('尚未保存，关闭后可能丢失'), findsOneWidget);
      await tester.tap(find.text('收起提示'));
      await tester.pump();
      expect(find.text('未保存'), findsOneWidget);
      disk.failPreferences = false;
      app.read(preferenceWriterProvider.notifier).retry();
      await pumpPresentation(tester);
      expect(status, findsNothing);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one persistent status leaves layout stable; collapse, routes and partial retry',
    (tester) async {
      final disk = SplitFaultPrefs();
      final app = await pumpYike(tester, preferences: disk);
      final dial = find.byType(YikeDial).first;
      final before = tester.getRect(dial);
      disk.failSnapshot = disk.failPreferences = true;
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(sound: false));
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await pumpPresentation(tester);
      final status = find.byKey(const ValueKey('unsaved-status'));
      expect(status, findsOneWidget);
      expect(tester.getRect(dial), before);
      final element = tester.element(status);
      await tester.tap(find.text('重试保存'));
      await pumpPresentation(tester);
      expect(tester.element(status), same(element));
      await tester.tap(find.text('收起提示'));
      await tester.pump();
      expect(find.text('未保存'), findsOneWidget);
      await navigateTab(tester, '打卡');
      expect(tester.element(status), same(element));
      await tester.tap(find.text('未保存'));
      await tester.pump();
      expect(find.text('尚未保存，关闭后可能丢失'), findsOneWidget);
      disk.failSnapshot = false;
      await tester.tap(find.text('重试保存'));
      await pumpPresentation(tester);
      expect(app.read(localDataProvider).writeError, isNull);
      expect(app.read(preferenceWriterProvider), isNotEmpty);
      expect(tester.element(status), same(element));
      appNavigatorKey.currentState!.pushNamed(
        AppRoutes.habitDetail,
        arguments: 'habit-water',
      );
      await pumpPresentation(tester);
      expect(status, findsOneWidget);
      disk.failPreferences = false;
      await tester.tap(find.text('重试保存'));
      await pumpPresentation(tester);
      expect(status, findsNothing);
      expect(app.read(preferenceWriterProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'modal nesting suspends status until actual dismissal; keyboard and form stay usable',
    (tester) async {
      final disk = SplitFaultPrefs();
      final app = await pumpYike(tester, preferences: disk);
      disk.failSnapshot = true;
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(sound: false));
      await pumpPresentation(tester);
      final status = find.byKey(const ValueKey('unsaved-status'));
      final element = tester.element(status);
      final context = appNavigatorKey.currentContext!;
      AppSheetActions<void>? outer, inner;
      final controller = TextEditingController(text: '仍可输入');
      addTearDown(controller.dispose);
      final closed = AppPop.sheet<void>(
        context,
        title: '第一层',
        builder: (_, actions) {
          outer = actions;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller),
              TextButton(
                onPressed: () {
                  unawaited(
                    AppPop.sheet<void>(
                      context,
                      title: '第二层',
                      builder: (_, actions) {
                        inner = actions;
                        return const Text('嵌套内容');
                      },
                    ),
                  );
                },
                child: const Text('再打开'),
              ),
            ],
          );
        },
      );
      await pumpPresentation(tester);
      expect((app.read(popupActivityProvider) > 0), isTrue);
      expect(status, findsNothing);
      expect(
        find.byKey(const ValueKey('unsaved-status'), skipOffstage: false),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '草稿未丢失');
      await tester.tap(find.text('再打开'));
      await pumpPresentation(tester);
      expect(app.read(popupActivityProvider), 2);
      unawaited(inner!.dismiss());
      await pumpPresentation(tester);
      expect(app.read(popupActivityProvider), 1);
      expect(status, findsNothing);
      expect(controller.text, '草稿未丢失');
      unawaited(outer!.dismiss());
      await tester.pump();
      expect((app.read(popupActivityProvider) > 0), isTrue);
      await pumpPresentation(tester);
      await closed;
      expect((app.read(popupActivityProvider) > 0), isFalse);
      expect(status, findsOneWidget);
      expect(tester.element(status), same(element));
      disk.failSnapshot = false;
      await tester.tap(find.text('重试保存'));
      await pumpPresentation(tester);
      expect(status, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-frame preference recovery never flashes; exit failure keeps new error; disposal clears',
    (tester) async {
      final disk = SplitFaultPrefs();
      final app = await pumpYike(tester, preferences: disk);
      disk.failPreferences = true;
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      disk.failPreferences = false;
      app.read(preferenceWriterProvider.notifier).retry();
      await tester.pump();
      expect(find.byKey(const ValueKey('unsaved-status')), findsNothing);
      disk.failSnapshot = true;
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(sound: false));
      await pumpPresentation(tester);
      disk.failSnapshot = false;
      app.read(localDataProvider.notifier).retry();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      disk.failSnapshot = true;
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(sound: true));
      await pumpPresentation(tester);
      expect(find.byKey(const ValueKey('unsaved-status')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPresentation(tester);
      final reopened = await pumpYike(tester, preferences: disk);
      expect(reopened.read(popupActivityProvider), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'retry saves accepted checkin without another event or a duplicate fact',
    (tester) async {
      final disk = SplitFaultPrefs();
      final app = await pumpYike(tester, preferences: disk);
      await navigateTab(tester, '打卡');
      disk.failSnapshot = true;
      await tester.tap(find.byKey(const ValueKey('check-habit-water')));
      await pumpPresentation(tester);
      final before = app.read(habitsProvider).first.checkins.values.single.id;
      disk.failSnapshot = false;
      await tester.tap(find.text('重试保存'));
      await pumpPresentation(tester);
      expect(app.read(habitsProvider).first.checkins.values.single.id, before);
      expect(find.byKey(const ValueKey('unsaved-status')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
