import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/settings/pages/settings_page.dart';
import 'package:yike/theme/ts.dart';

import 'support/pump_presentation.dart';
import 'yike_ui_test.dart' show pumpYike;

final _navigation = find.byKey(const ValueKey('settings-navigation'));
const _labels = ['外观', '番茄钟', '倒计时', '声音', '通用'];

void _expectSingleLineNavigation(WidgetTester tester, {bool scaled = false}) {
  final tabs = tester.widget<CommonPrimaryTabs>(_navigation);
  expect(tabs.grow, isTrue);
  expect(tabs.fitLabels, isTrue);
  final tabBar = tester.widget<TabBar>(
    find.descendant(of: _navigation, matching: find.byType(TabBar)),
  );
  expect(tabBar.isScrollable, isFalse);
  final factors = <double>[];
  final tops = <double>[];
  for (final label in _labels) {
    final text = find.descendant(of: _navigation, matching: find.text(label));
    expect(text.hitTestable(), findsOneWidget);
    final widget = tester.widget<Text>(text);
    expect(widget.maxLines, 1);
    expect(widget.softWrap, isFalse);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: label.length),
    );
    expect(boxes.map((box) => box.top).toSet(), hasLength(1));
    final fitted = tester.renderObject<RenderFittedBox>(
      find.ancestor(of: text, matching: find.byType(FittedBox)).first,
    );
    factors.add(fitted.child!.getTransformTo(fitted).storage[0]);
    tops.add(tester.getRect(text).top);
  }
  for (final factor in factors) {
    expect(factor, closeTo(factors.first, .001));
    expect(factor, lessThanOrEqualTo(1));
  }
  if (scaled) expect(factors.first, lessThan(1));
  for (final top in tops) {
    expect(top, closeTo(tops.first, .1));
  }
  expect(tester.takeException(), isNull);
}

double _borderWidth(WidgetTester tester, String theme) {
  final ink = tester.widget<InkWell>(find.byKey(ValueKey('theme-yike/$theme')));
  final decoration = (ink.child! as Container).decoration! as BoxDecoration;
  return (decoration.border! as Border).top.width;
}

void main() {
  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final large in [false, true]) {
      testWidgets('$theme settings labels fit one line, large=$large', (
        tester,
      ) async {
        if (large) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.8;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        await pumpYike(
          tester,
          theme: theme,
          size: large ? const Size(320, 640) : const Size(390, 844),
        );
        await tester.tap(find.byTooltip('设置'));
        await pumpPresentation(tester);
        _expectSingleLineNavigation(tester, scaled: large);
        final list = tester.widget<CustomScrollView>(
          find.descendant(
            of: find.byType(YikeSettingsPage),
            matching: find.byType(CustomScrollView),
          ),
        );
        list.controller!.jumpTo(90);
        await pumpPresentation(tester);
        _expectSingleLineNavigation(tester, scaled: large);
        await tester.tap(
          find.descendant(of: _navigation, matching: find.text('通用')),
        );
        await pumpPresentation(tester);
        expect(
          tester.widget<CommonPrimaryTabs>(_navigation).controller!.index,
          4,
        );
      });
    }
  }

  testWidgets('fitted controlled tabs keep selection under caller control', (
    tester,
  ) async {
    final controller = TabController(length: _labels.length, vsync: tester);
    addTearDown(controller.dispose);
    String? requested;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: CommonPrimaryTabs(
                  key: const ValueKey('settings-navigation'),
                  controller: controller,
                  items: [
                    for (var i = 0; i < _labels.length; i++)
                      CommonTabItem(value: '$i', label: _labels[i]),
                  ],
                  grow: true,
                  fitLabels: true,
                  compactLabels: true,
                  onSelectionRequested: (value) => requested = value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _expectSingleLineNavigation(tester, scaled: true);
    await tester.tap(
      find.descendant(of: _navigation, matching: find.text('倒计时')),
    );
    expect(requested, '2');
    expect(controller.index, 0);
  });

  testWidgets(
    'theme border follows the page and navigation stays stable in every frame',
    (tester) async {
      final app = await pumpYike(tester);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      final controller = tester
          .widget<CommonPrimaryTabs>(_navigation)
          .controller;
      final idleWidth = _borderWidth(tester, 'water');
      final selectedWidth = _borderWidth(tester, 'mechanical');
      await tester.tap(find.byKey(const ValueKey('theme-yike/water')));
      await tester.pump();
      expect(app.read(themePackProvider).id, 'yike/water');
      expect(_borderWidth(tester, 'water'), closeTo(idleWidth, .001));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_borderWidth(tester, 'water'), greaterThan(idleWidth));
      expect(_borderWidth(tester, 'water'), lessThan(selectedWidth));
      for (var i = 0; i < 10; i++) {
        _expectSingleLineNavigation(tester);
        expect(
          tester.widget<CommonPrimaryTabs>(_navigation).controller,
          same(controller),
        );
        expect(controller!.index, 0);
        await tester.pump(const Duration(milliseconds: 40));
      }
      final context = tester.element(find.byType(YikeSettingsPage));
      expect(_borderWidth(tester, 'water'), TS.of(context).border.focus.width);

      final list = tester.widget<CustomScrollView>(
        find.descendant(
          of: find.byType(YikeSettingsPage),
          matching: find.byType(CustomScrollView),
        ),
      );
      list.controller!.jumpTo(90);
      await pumpPresentation(tester);
      final offset = list.controller!.offset;
      // Reverse an unfinished transition without rebuilding the page or its tabs.
      final state = tester.state(find.byType(YikeSettingsPage));
      app.read(themePackProvider.notifier).select('yike/sundial');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final before = _borderWidth(tester, 'water');
      app.read(themePackProvider.notifier).select('yike/water');
      await tester.pump();
      expect(_borderWidth(tester, 'water'), closeTo(before, .001));
      await pumpPresentation(tester);
      expect(tester.state(find.byType(YikeSettingsPage)), same(state));
      expect(list.controller!.offset, closeTo(offset, .01));
      _expectSingleLineNavigation(tester);
    },
  );

  testWidgets(
    'reduced motion applies theme and selection together immediately',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpYike(tester);
      await tester.tap(find.byTooltip('设置'));
      await pumpPresentation(tester);
      await tester.tap(find.byKey(const ValueKey('theme-yike/sundial')));
      await tester.pump();
      final ts = TS.of(tester.element(find.byType(YikeSettingsPage)));
      expect(ts.pack.id, 'yike/sundial');
      expect(_borderWidth(tester, 'sundial'), ts.border.focus.width);
      _expectSingleLineNavigation(tester);
    },
  );
}
