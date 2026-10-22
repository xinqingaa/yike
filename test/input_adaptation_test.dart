import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_popups/unified_popups.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/theme/app_metrics.dart';
import 'package:yike/theme/ts.dart';

Widget shell(Widget Function(BuildContext) body, {double textScale = 1}) =>
    AppViewport(
      builder: (_, metrics) => ProviderScope(
        child: MaterialApp(
          theme: TS(
            brightness: Brightness.light,
            metrics: metrics,
            pack: generatedThemePacks.last,
          ).toThemeData(),
          navigatorObservers: [Pop.routeObserver],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Pop.hostBuilder(context, child!),
          ),
          home: Scaffold(body: Builder(builder: body)),
        ),
      ),
    );

void viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Finder image(CommonIconName name) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == name.assetPath,
);

void main() {
  testWidgets('input adornments keep glyph size inside the interaction slot', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    late TS ts;
    await tester.pumpWidget(
      shell((context) {
        ts = TS.of(context);
        return Column(
          children: [
            const CommonSearchBar(),
            CommonMenuField<String>(
              value: 'a',
              clearable: true,
              options: const [CommonChoiceOption(value: 'a', label: '选项 A')],
              onChanged: (_) {},
            ),
          ],
        );
      }),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(image(CommonIconName.search)),
      Size.square(ts.sizing.iconCompact),
    );
    expect(
      tester.getSize(image(CommonIconName.x)),
      Size.square(ts.sizing.iconMd),
    );
    expect(
      tester.getSize(find.byTooltip('清除')).shortestSide,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short drop menu shrinks to its options using library layout', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    late TS ts;
    await tester.pumpWidget(
      shell((context) {
        ts = TS.of(context);
        return Center(
          child: CommonMenuField<String>(
            hint: '短菜单',
            options: const [
              CommonChoiceOption(value: 'a', label: '短选项 A'),
              CommonChoiceOption(value: 'b', label: '短选项 B'),
              CommonChoiceOption(value: 'c', label: '短选项 C'),
            ],
            onChanged: (_) {},
          ),
        );
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('短菜单'));
    await tester.pumpAndSettle();
    final panel = find
        .ancestor(of: find.text('短选项 A'), matching: find.byType(Material))
        .first;
    final bounds = tester.getRect(panel);
    expect(bounds.height, lessThan(ts.layout.menuMaxHeight));
    expect(bounds.width, lessThan(390));
    await tester.tap(find.text('短选项 B'));
    await tester.pumpAndSettle();
    expect(find.text('短选项 A'), findsNothing);
  });

  testWidgets('password visibility belongs to each component instance', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(
        (_) => const Column(
          children: [
            CommonTextField(
              key: ValueKey('first-password'),
              obscureText: true,
              revealable: true,
            ),
            CommonTextField(
              key: ValueKey('second-password'),
              obscureText: true,
              revealable: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('显示密码').first);
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].obscureText, isFalse);
    expect(fields[1].obscureText, isTrue);
  });

  testWidgets(
    'search observes the current external controller after replacement',
    (tester) async {
      final first = TextEditingController(text: 'first');
      final second = TextEditingController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(shell((_) => CommonSearchBar(controller: first)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('清除'), findsOneWidget);
      await tester.pumpWidget(
        shell((_) => CommonSearchBar(controller: second)),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('清除'), findsNothing);
      first.text = 'detached';
      await tester.pump();
      expect(find.byTooltip('清除'), findsNothing);
      second.text = 'active';
      await tester.pump();
      expect(find.byTooltip('清除'), findsOneWidget);
      await tester.tap(find.byTooltip('清除'));
      await tester.pump();
      expect(second.text, isEmpty);
      expect(first.text, 'detached');
    },
  );

  for (final keyboard in [0.0, 240.0]) {
    testWidgets('long menu fits the screen with keyboard inset $keyboard', (
      tester,
    ) async {
      viewport(tester, const Size(320, 640));
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
      tester.view.padding = FakeViewPadding(
        top: 24,
        bottom: keyboard > 0 ? 0 : 20,
      );
      String? selected;
      await tester.pumpWidget(
        shell(
          (_) => SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: CommonMenuField<String>(
                  hint: '打开选择',
                  options: List.generate(
                    20,
                    (i) => CommonChoiceOption(value: '$i', label: '菜单选项 $i'),
                  ),
                  onChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开选择'));
      await tester.pumpAndSettle();
      final first = find.text('菜单选项 0');
      expect(first, findsOneWidget);
      final panel = find
          .ancestor(of: first, matching: find.byType(Material))
          .first;
      final rect = tester.getRect(panel);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(24));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(
        rect.bottom,
        lessThanOrEqualTo(640 - (keyboard > 20 ? keyboard : 20)),
      );
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(selected, '0');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'viewport resizing updates tokens once and retains system text scaling',
    (tester) async {
      viewport(tester, const Size(390, 844));
      late TS ts;
      await tester.pumpWidget(
        shell((context) {
          ts = TS.of(context);
          return Text('正文', style: ts.textStyle.content);
        }, textScale: 1.4),
      );
      await tester.pumpAndSettle();
      final originalWidth = ts.sizing.actionMinInline;
      final originalIcon = ts.sizing.iconMd;
      expect(ts.textStyle.content.fontSize, lessThanOrEqualTo(14));
      expect(ts.textStyle.title.fontSize, lessThanOrEqualTo(18));
      final paragraph = tester.renderObject<RenderParagraph>(find.text('正文'));
      expect(paragraph.textScaler.scale(10), closeTo(14, 0.001));
      tester.view.physicalSize = const Size(320, 700);
      await tester.pumpAndSettle();
      expect(ts.sizing.actionMinInline, lessThanOrEqualTo(originalWidth));
      expect(ts.sizing.iconMd, lessThan(originalIcon));
      final compact = ts.sizing.iconMd;
      await tester.pump();
      expect(ts.sizing.iconMd, compact);
      expect(ts.pack.sizing.iconMd, 20);
    },
  );
}
