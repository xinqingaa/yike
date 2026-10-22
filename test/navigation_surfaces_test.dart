import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/theme/ts.dart';

void main() {
  for (final pack in generatedThemePacks) {
    for (final brightness in Brightness.values) {
      testWidgets('${pack.id}/$brightness navigation surface policy', (
        tester,
      ) async {
        final ts = TS(brightness: brightness, pack: pack);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ts.toThemeData(),
              home: Scaffold(
                appBar: const CommonAppBar(title: '标题'),
                bottomNavigationBar: CommonBottomNav(
                  items: const [
                    CommonBottomNavItem(
                      value: 'home',
                      label: '首页',
                      icon: CommonIconName.home,
                    ),
                    CommonBottomNavItem(
                      value: 'list',
                      label: '列表',
                      icon: CommonIconName.list,
                    ),
                  ],
                  currentIndex: 0,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        );
        final bar = tester.widget<AppBar>(find.byType(AppBar));
        expect(
          bar.systemOverlayStyle!.statusBarIconBrightness,
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        );
        expect(bar.systemOverlayStyle!.statusBarBrightness, brightness);
        if (pack.surfaceTreatment == AppSurfaceTreatment.glass) {
          final glass = tester.widget<CommonGlassSurface>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(CommonGlassSurface),
            ),
          );
          expect(glass.edges, CommonGlassEdges.bottom);
          expect(bar.shape, isNull);
        }
        final selection = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(AnimatedPositioned),
            matching: find.byType(DecoratedBox),
          ),
        );
        final radius =
            (selection.decoration as BoxDecoration).borderRadius
                as BorderRadius;
        final expected = switch (pack.id) {
          'yike/water' => 18.0,
          'yike/sundial' => 2.0,
          _ => (ts.radius.lg - ts.spacing.xs).clamp(0.0, double.infinity),
        };
        expect(radius.topLeft.x, expected);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
