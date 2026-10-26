import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/overlay/duration_sheet.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/features/review/widgets/period_picker.dart';
import 'package:yike/features/review/models/review_period.dart';

import 'support/pump_presentation.dart';
import 'yike_ui_test.dart' show pumpYike, navigateTab;

Finder settingsTab(String label) => find.descendant(
  of: find.byKey(const ValueKey('settings-navigation')),
  matching: find.text(label),
);

Future<void> selectSettings(WidgetTester tester, String label) async {
  if (settingsTab(label).hitTestable().evaluate().isEmpty) {
    await tester.drag(
      find.byKey(const ValueKey('settings-navigation')),
      const Offset(-200, 0),
    );
    await pumpPresentation(tester);
  }
  await tester.tap(settingsTab(label));
  await pumpPresentation(tester);
}

void main() {
  testWidgets(
    'mode swipes synchronize business selection and preserve running sessions',
    (tester) async {
      final app = await pumpYike(tester);
      await tester.tap(find.text('开始专注'));
      await pumpPresentation(tester);
      final id = app.read(focusDataProvider).session!.id;
      await tester.drag(
        find.descendant(
          of: find.byType(FocusPage),
          matching: find.byType(CommonTabView),
        ),
        const Offset(-320, 0),
      );
      await pumpPresentation(tester);
      expect(app.read(focusDataProvider).mode, TimerMode.stopwatch);
      expect(
        app.read(focusDataProvider).sessionFor(TimerMode.pomodoro)!.id,
        id,
      );
      expect(
        app.read(focusDataProvider).sessionFor(TimerMode.pomodoro)!.status,
        TimerStatus.running,
      );
      expect(find.text('剩余'), findsNothing);
      expect(find.text('拨动调整'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings section taps and manual scrolling share one pinned navigation',
    (tester) async {
      await pumpYike(tester);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      final nav = find.byKey(const ValueKey('settings-navigation'));
      CommonPrimaryTabs tabs() => tester.widget<CommonPrimaryTabs>(nav);
      expect(tabs().controller!.index, 0);
      expect(tabs().glassReveal, 0);
      final header = tester.widget<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      final list = tester.widget<CustomScrollView>(
        find.descendant(
          of: find.byType(YikeSettingsPage),
          matching: find.byType(CustomScrollView),
        ),
      );
      list.controller!.jumpTo(
        header.delegate.maxExtent - header.delegate.minExtent + 90,
      );
      await pumpPresentation(tester);
      expect(tabs().glassReveal, closeTo(.5, .01));
      expect(tabs().clear, isTrue);
      final midWidth = tester.getSize(nav).width;
      list.controller!.jumpTo(180);
      await pumpPresentation(tester);
      expect(tester.getSize(nav).width, 390);
      expect(midWidth, lessThan(390));
      list.controller!.jumpTo(0);
      await pumpPresentation(tester);
      await selectSettings(tester, '番茄钟');
      expect(tabs().controller!.index, 1);
      expect(tabs().glassReveal, 1);
      expect(find.text('经典').hitTestable(), findsOneWidget);
      final scroll = tester.widget<CustomScrollView>(
        find.descendant(
          of: find.byType(YikeSettingsPage),
          matching: find.byType(CustomScrollView),
        ),
      );
      scroll.controller!.jumpTo(scroll.controller!.position.maxScrollExtent);
      await pumpPresentation(tester);
      expect(tabs().controller!.index, 4);
      await selectSettings(tester, '外观');
      expect(scroll.controller!.offset, 0);
      expect(tabs().controller!.index, 0);
      expect(tabs().glassReveal, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings keeps scheme choices and advanced controls out of the default view',
    (tester) async {
      final app = await pumpYike(tester);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      await selectSettings(tester, '番茄钟');
      expect(find.text('轻量'), findsNothing);
      expect(find.text('深度'), findsNothing);
      expect(
        find.byKey(const ValueKey('pomodoro/interval')).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('pomodoro/scheme')));
      await pumpPresentation(tester);
      await tester.tap(find.text('深度'));
      await pumpPresentation(tester);
      expect(app.read(timingPreferencesProvider).focusSeconds, 3000);
      expect(find.text('深度').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pomodoro-advanced')));
      await pumpPresentation(tester);
      expect(
        find.byKey(const ValueKey('pomodoro/interval')).hitTestable(),
        findsOneWidget,
      );
      await selectSettings(tester, '通用');
      expect(
        find.byKey(const ValueKey('settings-reset')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('feedback/audition')).hitTestable(),
        findsNothing,
      );
      await selectSettings(tester, '声音');
      expect(
        find.byKey(const ValueKey('feedback/audition')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('feedback/audition')));
      await pumpPresentation(tester);
      expect(find.text('间隔提示').hitTestable(), findsOneWidget);
      await tester.tap(find.text('间隔提示').last);
      await pumpPresentation(tester);
      expect(find.textContaining('试听中'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preset editor expands inline and restore requires confirmation',
    (tester) async {
      final app = await pumpYike(tester);
      app
          .read(timingPreferencesProvider.notifier)
          .update((p) => p.copyWith(presets: [181, 300, 600, 1200]));
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      await selectSettings(tester, '倒计时');
      await tester.tap(find.byTooltip('打开常用倒计时'));
      await pumpPresentation(tester);
      expect(find.byType(DurationWheels).hitTestable(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('preset-row-0')));
      await pumpPresentation(tester);
      expect(find.byType(DurationWheels).hitTestable(), findsOneWidget);
      final visibleWheel = find.byType(CommonWheelPicker).hitTestable();
      expect(tester.widget<CommonWheelPicker>(visibleWheel).visibleRows, 5);
      expect(find.byTooltip('返回上一步'), findsNothing);
      await tester.tap(find.text('恢复默认'));
      await pumpPresentation(tester);
      expect(find.text('恢复常用倒计时？'), findsOneWidget);
      await tester.tap(find.text('保留当前'));
      await pumpPresentation(tester);
      expect(app.read(timingPreferencesProvider).presets.first, 181);
      await tester.tap(find.text('恢复默认'));
      await pumpPresentation(tester);
      final confirm = find.widgetWithText(CommonButton, '恢复默认').last;
      await tester.tap(confirm);
      await pumpPresentation(tester);
      expect(app.read(timingPreferencesProvider).presets, [
        180,
        300,
        600,
        1200,
      ]);
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review uses explicit current-period action and a scrollable year picker',
    (tester) async {
      await pumpYike(tester);
      await navigateTab(tester, '回顾');
      expect(find.text('本周'), findsOneWidget);
      expect(find.byTooltip('返回当前周期'), findsNothing);
      expect(find.byType(CommonDivider), findsNothing);
      await tester.tap(find.byKey(const ValueKey('review-period-picker')));
      await pumpPresentation(tester);
      expect(find.text('2026年'), findsOneWidget);
      await tester.tap(find.byTooltip('上一年'));
      await pumpPresentation(tester);
      expect(find.text('2025年'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
    },
  );

  testWidgets(
    'narrow large text keeps setting controls and period choices reachable',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpYike(tester, size: const Size(320, 640));
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      await selectSettings(tester, '番茄钟');
      expect(tester.takeException(), isNull);
      await selectSettings(tester, '倒计时');
      await tester.tap(find.byTooltip('打开常用倒计时'));
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('preset-row-0')));
      await pumpPresentation(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
      await tester.tap(find.byTooltip('返回'));
      await pumpPresentation(tester);
      await navigateTab(tester, '回顾');
      await tester.tap(find.byKey(const ValueKey('review-period-picker')));
      await pumpPresentation(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await pumpPresentation(tester);
    },
  );

  test('period labels retain complete padded dates on both sides', () {
    expect(
      reviewPeriodLabel(ReviewSelection(anchor: DateTime.utc(2026, 10, 26))),
      '10月26日 – 11月01日',
    );
    expect(
      reviewPeriodLabel(ReviewSelection(anchor: DateTime.utc(2026, 1, 5))),
      '01月05日 – 01月11日',
    );
    expect(
      reviewPeriodLabel(
        ReviewSelection(anchor: DateTime.utc(2026, 1), month: true),
      ),
      '2026年01月',
    );
  });
}
