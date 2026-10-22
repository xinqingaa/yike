import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yike/common/widgets.dart';
import 'package:yike/common/widgets/navigation/liquid_glass_decoration.dart';
import 'package:yike/theme/proto_bridge_tokens.dart';
import 'package:yike/theme/ts.dart';

void main() {
  final ts = TS(brightness: Brightness.light);
  test('machine token mappings match the executable TS snapshot', () {
    final contract =
        jsonDecode(File('proto-bridge.target.json').readAsStringSync())
            as Map<String, Object?>;
    final mappings = contract['tokens']! as Map<String, Object?>;
    final components = contract['components']! as Map<String, Object?>;

    expect(mappings, isNotEmpty);
    expect(components, isNotEmpty);
    expect(mappings, isNot(contains('transparent')));
    expect(mappings, isNot(contains('none')));

    // The target is mid-migration: entries may be pending while the matching
    // Producer surface is being adapted. A concrete entry must point at a
    // public Dart symbol/accessor and its import; a pending entry must carry a
    // non-empty reason. Exact key equality with the Producer catalog is
    // enforced by `pnpm ds:target-sync:verify`, not duplicated here.
    for (final entry in mappings.entries) {
      final mapping = entry.value as Map<String, Object?>;
      if (mapping['status'] == 'pending') {
        expect(
          (mapping['reason'] as String?)?.trim(),
          isNotEmpty,
          reason: '${entry.key} is pending without a reason.',
        );
        continue;
      }
      expect(
        mapping['import'],
        isA<String>(),
        reason: '${entry.key} has no import.',
      );
      expect(
        mapping['symbol'] ?? mapping['accessor'],
        isA<String>(),
        reason: '${entry.key} has no symbol/accessor.',
      );
    }

    for (final entry in components.entries) {
      final mapping = entry.value as Map<String, Object?>;
      if (mapping['status'] == 'pending') {
        expect(
          (mapping['reason'] as String?)?.trim(),
          isNotEmpty,
          reason: '${entry.key} is pending without a reason.',
        );
        continue;
      }
      expect(
        mapping['import'],
        isA<String>(),
        reason: '${entry.key} has no import.',
      );
      expect(
        mapping['symbol'],
        isA<String>(),
        reason: '${entry.key} has no symbol.',
      );
    }

    final snapshotKeys = protoBridgeTokenSnapshot(ts).keys.toSet();
    expect(snapshotKeys, isNotEmpty);
    expect(snapshotKeys, mappings.keys.toSet());
    for (final entry in mappings.entries) {
      final mapping = entry.value as Map<String, Object?>;
      if (mapping['status'] == 'pending') continue;
      expect(
        snapshotKeys,
        contains(entry.key),
        reason: '${entry.key} is mapped but has no executable accessor.',
      );
    }
  });

  testWidgets(
    'Tabbar keeps native icon-label navigation with one moving material',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TS(brightness: Brightness.light).toThemeData(),
            home: Scaffold(
              bottomNavigationBar: CommonBottomNav(
                currentIndex: 0,
                onTap: (_) {},
                items: const [
                  CommonBottomNavItem(
                    value: 'home',
                    label: '首页',
                    icon: CommonIconName.home,
                  ),
                  CommonBottomNavItem(
                    value: 'tasks',
                    label: '任务',
                    icon: CommonIconName.list,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('首页'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  CommonIconName.home.assetPath,
        ),
        findsOneWidget,
      );
      expect(find.byType(AnimatedPositioned), findsOneWidget);
    },
  );

  testWidgets(
    'primary tabs use one glass track and native indicator geometry',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TS(brightness: Brightness.light).toThemeData(),
            home: const Scaffold(
              body: DefaultTabController(
                length: 2,
                child: CommonPrimaryTabs(
                  items: [
                    CommonTabItem(value: 'all', label: '全部'),
                    CommonTabItem(value: 'done', label: '完成'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CommonGlassSurface), findsOneWidget);

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final selection = tabBar.indicator! as LiquidGlassDecoration;
      expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);
      expect(tabBar.indicatorAnimation, TabIndicatorAnimation.linear);
      expect(
        tabBar.indicatorPadding,
        EdgeInsets.symmetric(vertical: ts.spacing.xs),
      );
      expect(selection.surfaceColor, ts.colors.primaryTabsSelectionTint);
      expect(selection.opacity, ts.opacity.translucent);
      expect(selection.borderRadius, BorderRadius.circular(ts.radius.sm));
      expect(selection.shadow, ts.elevation.floating);
      expect(
        tester.getSize(find.byKey(const ValueKey('primary-tabs-track'))).height,
        ts.sizing.controlMd + ts.spacing.xs * 2,
      );
      expect(
        tester.getSize(find.byType(TabBar)).height -
            tabBar.indicatorPadding.vertical,
        ts.sizing.controlMd,
      );
    },
  );

  testWidgets('primary indicator follows a TabBarView drag before it settles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: const Scaffold(
            body: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  CommonPrimaryTabs(
                    grow: true,
                    items: [
                      CommonTabItem(value: 'all', label: '全部'),
                      CommonTabItem(value: 'done', label: '完成'),
                    ],
                  ),
                  Expanded(
                    child: CommonTabView(
                      children: [Text('全部内容'), Text('完成内容')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final tabContext = tester.element(find.byType(CommonPrimaryTabs));
    final controller = DefaultTabController.of(tabContext);
    expect(controller.animation!.value, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TabBarView)),
    );
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();

    expect(controller.animation!.value, greaterThan(0));
    expect(controller.animation!.value, lessThan(1));
    expect(
      tester.widget<TabBar>(find.byType(TabBar)).indicator,
      isA<LiquidGlassDecoration>(),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.index, 0);
  });

  testWidgets('primary grow mode honors a non-first initial index', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: const Scaffold(
            body: DefaultTabController(
              length: 3,
              initialIndex: 1,
              child: CommonPrimaryTabs(
                grow: true,
                items: [
                  CommonTabItem(value: 'short', label: '短'),
                  CommonTabItem(value: 'middle', label: '较长标签'),
                  CommonTabItem(value: 'long', label: '第三项'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final controller = DefaultTabController.of(
      tester.element(find.byType(CommonPrimaryTabs)),
    );
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(controller.index, 1);
    expect(controller.animation!.value, 1);
    expect(tabBar.isScrollable, isFalse);
    expect(tabBar.tabAlignment, TabAlignment.fill);
    expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);
  });

  testWidgets('primary track fills a loosely constrained parent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: const Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTabController(
                  length: 2,
                  child: CommonPrimaryTabs(
                    items: [
                      CommonTabItem(value: 'short', label: '短'),
                      CommonTabItem(value: 'long', label: '较长标签'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('primary-tabs-track'))).width,
      390,
    );
  });

  testWidgets(
    'secondary tabs use compact label spacing and controlled height',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TS(brightness: Brightness.light).toThemeData(),
            home: const Scaffold(
              body: DefaultTabController(
                length: 2,
                child: CommonSecondaryTabs(
                  items: [
                    CommonTabItem(value: 'all', label: '全部'),
                    CommonTabItem(value: 'done', label: '完成'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        tabBar.labelPadding,
        EdgeInsets.symmetric(horizontal: ts.spacing.sm),
      );
      expect(
        tester.widgetList<Tab>(find.byType(Tab)).map((tab) => tab.height),
        everyElement(ts.sizing.controlMd),
      );
    },
  );

  test('dark theme consumes the Producer translucent-opacity override', () {
    expect(TS(brightness: Brightness.light).opacity.translucent, 0.76);
    expect(TS(brightness: Brightness.dark).opacity.translucent, 0.8);
  });

  test('floating elevation keeps the Producer selection shadow', () {
    final light = TS(brightness: Brightness.light).elevation.floating;
    final dark = TS(brightness: Brightness.dark).elevation.floating;

    expect(light.blurRadius, 18);
    expect(light.offset, const Offset(0, 6));
    expect(light.color, const Color.fromRGBO(15, 23, 42, 0.08));
    expect(dark.blurRadius, 18);
    expect(dark.offset, const Offset(0, 6));
    expect(dark.color, const Color.fromRGBO(0, 0, 0, 0.28));
  });

  test('default page transitions use iOS on every platform', () {
    final theme = TS(brightness: Brightness.light).toThemeData();
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(PbPageTransitions.android, isA<ZoomPageTransitionsBuilder>());
    expect(
      PbPageTransitions.theme(
        mode: PbPageTransitionMode.android,
      ).builders[TargetPlatform.android],
      isA<ZoomPageTransitionsBuilder>(),
    );
  });

  test('PBWork icons retain one 3x asset for every public identity', () {
    for (final name in CommonIconName.values) {
      expect(File(name.assetPath).existsSync(), isTrue);
    }
    expect(Directory('asset/base/icons/2.0x').existsSync(), isFalse);
    expect(Directory('asset/base/icons/3.0x').existsSync(), isFalse);
  });

  testWidgets('pull refresh settles at the boundary without a second rebound', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: Scaffold(
            body: CommonScrollableDataList(
              itemCount: 20,
              itemBuilder: (_, index) =>
                  SizedBox(height: 48, child: Text('row $index')),
              onRefresh: () async {
                refreshCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    final scrollableFinder = find.byType(Scrollable).first;
    await tester.drag(scrollableFinder, const Offset(0, 180));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    expect(refreshCount, 1);
    expect(scrollable.position.outOfRange, isFalse);
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.minScrollExtent, 0.5),
    );
  });

  testWidgets(
    'loading button retains its label and progress uses percent input',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: TS(brightness: Brightness.light).toThemeData(),
            home: const Scaffold(
              body: Column(
                children: [
                  CommonButton(label: '提交中', loading: true),
                  CommonProgress(value: 68),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('提交中'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(0.68, 0.001));
    },
  );

  testWidgets('button kinds use action tokens', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: const Scaffold(
            body: Column(
              children: [
                CommonButton(label: '主要'),
                CommonButton(label: '次要', kind: CommonButtonKind.secondary),
                CommonButton(label: '描边', kind: CommonButtonKind.outlined),
              ],
            ),
          ),
        ),
      ),
    );

    BoxDecoration decorationOf(String label) {
      return tester
              .widget<Ink>(
                find.descendant(
                  of: find.widgetWithText(CommonButton, label),
                  matching: find.byType(Ink),
                ),
              )
              .decoration!
          as BoxDecoration;
    }

    expect(decorationOf('主要').color, ts.colors.action);
    expect(decorationOf('次要').color, ts.colors.actionSoft);
    expect(decorationOf('描边').color, Colors.transparent);
    expect(decorationOf('描边').border?.top.color, ts.colors.outline);
  });

  testWidgets('unlabeled text fields fill with surface-recessed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TS(brightness: Brightness.light).toThemeData(),
          home: const Scaffold(body: CommonTextField(hint: '无标题输入')),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.fillColor, ts.colors.surfaceRecessed);
    expect(field.decoration?.border, InputBorder.none);
  });
}
