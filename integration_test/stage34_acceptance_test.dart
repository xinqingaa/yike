// Temporary native UI acceptance. Uses sample memory data and REAL feedback.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yike/app/app.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/home/pages/home_page.dart';
import 'package:yike/features/focus/widgets/lap_panel.dart';
import 'package:yike/features/review/pages/statistics_page.dart';
import 'package:yike/features/review/widgets/statistics_charts.dart';
import 'package:yike/features/review/widgets/day_data_card.dart';
import 'package:yike/features/review/widgets/day_detail_sheet.dart';
import 'package:yike/features/review/widgets/focus_year_plot.dart';
import 'package:yike/common/time.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/theme/ts.dart';
import '../tool/stage34_preview.dart' show stage34Preferences;
import '../test/support/pump_presentation.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> shot(WidgetTester tester, String name) async {
    await pumpPresentation(tester);
    await tester.runAsync(() async {
      final bytes = await binding.takeScreenshot(name);
      final file = File('${Directory.systemTemp.path}/yike-stage34-$name.png');
      await file.writeAsBytes(bytes);
      debugPrint('YIKE_STAGE34_SCREENSHOT=${file.path}');
    });
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await pumpPresentation(tester);
  }

  Future<void> root(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(
      of: find.byType(CommonBottomNav),
      matching: find.text(label),
    ),
  );
  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets('$theme stage34 native UI', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(
              stage34Preferences(DateTime.now(), theme: theme),
            ),
          ],
          child: const PbApp(),
        ),
      );
      if (Platform.isAndroid) {
        await tester.runAsync(binding.convertFlutterSurfaceToImage);
      }
      await pumpPresentation(tester);
      final app = ProviderScope.containerOf(
        tester.element(find.byType(YikeHomePage)),
      );
      await shot(tester, '$theme-focus');
      await tap(tester, find.byKey(const ValueKey('stopwatch-laps-entry')));
      await shot(tester, '$theme-laps-paused');
      await tap(tester, find.byKey(const ValueKey('lap-panel-pause')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.tap(find.byKey(const ValueKey('lap-panel-lap')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await shot(tester, '$theme-laps-running');
      await tap(tester, find.byKey(const ValueKey('lap-panel-pause')));
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await shot(tester, '$theme-laps-dark');
      await tap(tester, find.byTooltip('关闭计圈'));
      expect(find.byType(LapPanel), findsNothing);
      app.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await root(tester, '回顾');
      await shot(tester, '$theme-review');
      final dates = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('review-day-'),
      );
      await tester.longPress(dates.first);
      await shot(tester, '$theme-day-card');
      await tap(tester, find.text('查看当日记录'));
      await shot(tester, '$theme-day-detail');
      await tap(tester, find.byTooltip('关闭'));
      await tap(tester, find.byTooltip('统计'));
      await shot(tester, '$theme-statistics');
      final scroll = find
          .descendant(
            of: find.byType(StatisticsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scroll, const Offset(0, -420));
      await shot(tester, '$theme-statistics-types');
      final legend = find.descendant(
        of: find.byType(TypeDistribution),
        matching: find.text('正计时'),
      );
      if (legend.hitTestable().evaluate().isEmpty) {
        await tester.ensureVisible(legend);
      }
      await tap(tester, legend);
      await shot(tester, '$theme-statistics-type-selected');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await shot(tester, '$theme-statistics-type-dark');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await pumpPresentation(tester);

      await tester.drag(scroll, const Offset(0, -1100));
      await shot(tester, '$theme-statistics-year');
      await tap(tester, find.byTooltip('返回'));
      await root(tester, '打卡');
      await tap(
        tester,
        find.byKey(const ValueKey('habit-detail-preview-habit-0')),
      );
      await shot(tester, '$theme-habit');
      await tap(
        tester,
        find.byKey(
          ValueKey(
            'habit-day-${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
          ),
        ),
      );
      await shot(tester, '$theme-habit-card');
      expect(tester.takeException(), isNull);
    });
  }
  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets('$theme unified date menus and borderless grids', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(
              stage34Preferences(DateTime.now(), theme: theme),
            ),
          ],
          child: const PbApp(),
        ),
      );
      if (Platform.isAndroid) {
        await tester.runAsync(binding.convertFlutterSurfaceToImage);
      }
      await pumpPresentation(tester);
      final id = dayId(DateTime.now());
      final app = ProviderScope.containerOf(
        tester.element(find.byType(YikeHomePage)),
      );
      await root(tester, '回顾');
      final date = find.byKey(ValueKey('review-day-$id'));
      await tap(tester, date);
      expect(find.byType(DayDetailSheet), findsNothing);
      expect(find.text('查看当日记录'), findsOneWidget);
      await shot(tester, '$theme-unified-review-menu');
      await tap(tester, find.text('查看当日记录'));
      expect(find.byType(DayDetailSheet), findsOneWidget);
      await tap(tester, find.byTooltip('关闭'));
      final reviewType = find.text('番茄钟').last;
      await tester.ensureVisible(reviewType);
      await tap(tester, reviewType);
      await shot(tester, '$theme-unified-review-selected');
      final reviewScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const PageStorageKey('review-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      reviewScroll.position.jumpTo(0);
      await pumpPresentation(tester);
      await tap(tester, find.byTooltip('统计'));
      await Scrollable.ensureVisible(
        tester.element(find.byType(TypeDistribution)),
        alignment: .15,
      );
      await pumpPresentation(tester);
      await tap(
        tester,
        find.descendant(
          of: find.byType(TypeDistribution),
          matching: find.text('正计时'),
        ),
      );
      await shot(tester, '$theme-unified-statistics-selected');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await shot(tester, '$theme-unified-statistics-selected-dark');
      app.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await pumpPresentation(tester);
      final year = find.byType(FocusYearPlot);
      await Scrollable.ensureVisible(tester.element(year), alignment: .3);
      await pumpPresentation(tester);
      await shot(tester, '$theme-unified-year-blocks');
      final yearDate = find.descendant(
        of: year,
        matching: find.byWidgetPredicate(
          (w) => w is ReviewDayTarget && w.date == id,
        ),
      );
      await tap(tester, yearDate);
      expect(find.byType(DayDetailSheet), findsNothing);
      expect(find.text('查看当日记录'), findsNothing);
      await shot(tester, '$theme-unified-year-menu');
      await tap(tester, find.text('统计').first);
      final habit = find.byKey(ValueKey('habit-progress-preview-habit-0-$id'));
      await tester.ensureVisible(habit);
      await pumpPresentation(tester);
      await tap(tester, habit);
      expect(find.textContaining('当周完成'), findsOneWidget);
      expect(find.text('查看当日记录'), findsNothing);
      await shot(tester, '$theme-unified-statistics-habit-menu');
      // Dismiss the menu before navigating; back first belongs to the menu.
      await tap(tester, find.text('统计').first);
      expect(find.textContaining('当周完成'), findsNothing);
      await tap(tester, find.byTooltip('返回'));
      await root(tester, '打卡');
      await tap(
        tester,
        find.byKey(const ValueKey('habit-detail-preview-habit-0')),
      );
      await shot(tester, '$theme-unified-habit-blocks');
      await tap(tester, find.byKey(ValueKey('habit-day-$id')));
      await shot(tester, '$theme-unified-habit-menu');
      expect(find.textContaining('当周完成'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets('$theme native auto menu and heatmap contrast', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(
              stage34Preferences(DateTime.now(), theme: theme),
            ),
          ],
          child: const PbApp(),
        ),
      );
      if (Platform.isAndroid) {
        await tester.runAsync(binding.convertFlutterSurfaceToImage);
      }
      await pumpPresentation(tester);
      final app = ProviderScope.containerOf(
        tester.element(find.byType(YikeHomePage)),
      );
      await root(tester, '回顾');
      await tap(tester, find.byTooltip('统计'));
      final year = find.byType(FocusYearPlot);
      await Scrollable.ensureVisible(tester.element(year), alignment: .2);
      await pumpPresentation(tester);
      for (final dark in [false, true]) {
        app
            .read(themeModeProvider.notifier)
            .setMode(dark ? ThemeMode.dark : ThemeMode.light);
        await shot(
          tester,
          '$theme-menu-contrast-year-${dark ? 'dark' : 'light'}',
        );
        for (final ago in dark ? [0] : [0, 42, 84]) {
          final id = dayId(DateTime.now().subtract(Duration(days: ago)));
          final cell = find.descendant(
            of: year,
            matching: find.byWidgetPredicate(
              (w) => w is ReviewDayTarget && w.date == id,
            ),
          );
          if (ago == 42) {
            await tester.longPress(cell);
            await pumpPresentation(tester);
          } else {
            await tap(tester, cell);
          }
          expect(find.text('查看当日记录'), findsNothing);
          expect(find.byType(DayDetailSheet), findsNothing);
          final card = find
              .ancestor(
                of: find.text(dateWeekLabel(id)),
                matching: find.byType(TapRegion),
              )
              .first;
          final bounds = tester.getRect(card),
              screen = MediaQuery.sizeOf(tester.element(card));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(screen.width));
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(screen.height));
          await shot(tester, '$theme-menu-auto-${dark ? 'dark' : ago}');
          await tap(tester, find.text('统计').first);
        }
      }
      await tap(tester, find.byTooltip('返回'));
      await root(tester, '打卡');
      await tap(
        tester,
        find.byKey(const ValueKey('habit-detail-preview-habit-0')),
      );
      for (final dark in [false, true]) {
        app
            .read(themeModeProvider.notifier)
            .setMode(dark ? ThemeMode.dark : ThemeMode.light);
        await shot(
          tester,
          '$theme-menu-contrast-habit-${dark ? 'dark' : 'light'}',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('statistics ring selection and final legend spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(
            stage34Preferences(DateTime.now(), theme: 'mechanical'),
          ),
        ],
        child: const PbApp(),
      ),
    );
    if (Platform.isAndroid) {
      await tester.runAsync(binding.convertFlutterSurfaceToImage);
    }
    await pumpPresentation(tester);
    final app = ProviderScope.containerOf(
      tester.element(find.byType(YikeHomePage)),
    );
    await root(tester, '回顾');
    await tap(tester, find.byTooltip('统计'));
    await Scrollable.ensureVisible(
      tester.element(find.byType(TypeDistribution)),
      alignment: .2,
    );
    await pumpPresentation(tester);
    final legend = find.descendant(
      of: find.byType(TypeDistribution),
      matching: find.text('正计时'),
    );
    await tap(tester, legend);
    await shot(tester, 'mechanical-statistics-selection-final');
    app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await shot(tester, 'mechanical-statistics-selection-final-dark');
  });
  testWidgets('data cards stay within viewport at the right edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(
            stage34Preferences(DateTime.now(), theme: 'sundial'),
          ),
        ],
        child: const PbApp(),
      ),
    );
    await pumpPresentation(tester);
    await root(tester, '打卡');
    await tap(
      tester,
      find.byKey(const ValueKey('habit-detail-preview-habit-0')),
    );
    final now = DateTime.now();
    final id =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await tap(tester, find.byKey(ValueKey('habit-day-$id')));
    final card = find
        .ancestor(
          of: find.textContaining('当周完成'),
          matching: find.byType(TapRegion),
        )
        .first;
    final bounds = tester.getRect(card),
        screen = MediaQuery.sizeOf(tester.element(card));
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(screen.width));
    expect(bounds.top, greaterThanOrEqualTo(0));
    expect(bounds.bottom, lessThanOrEqualTo(screen.height));
    await shot(tester, 'sundial-habit-card');
  });
}
