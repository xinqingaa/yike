import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/motion/page_transition.dart';
import 'package:yike/common/motion/rolling_digits.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/common/widgets/yike/dial.dart';
import 'package:yike/features/habits/providers/habit_editor_presentation.dart';
import 'package:yike/features/habits/providers/habits_presentation.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/theme/ts.dart';
import '../features/local_data/local_data_test.dart' show FaultPrefs;
import '../support/pump_presentation.dart';
import '../yike_ui_test.dart' show pumpYike;

Widget shell(Widget child, {bool reduced = false}) {
  final ts = TS(brightness: Brightness.light, pack: generatedThemePacks.first);
  return MaterialApp(
    theme: ts.toThemeData(),
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reduced,
        boldText: true,
        textScaler: TextScaler.linear(1.6),
      ),
      child: Scaffold(
        body: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Ahem', letterSpacing: 9),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  for (final theme in ['mechanical', 'water', 'sundial']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$theme $brightness fits every glyph with inherited font and large text',
        (tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(boldText: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final ts = TS(
            brightness: brightness,
            pack: generatedThemePacks.firstWhere((p) => p.id == 'yike/$theme'),
          );
          Future<void> show(String digits) => tester.pumpWidget(
            shell(
              Center(
                child: YikeDial(
                  tokens: ts,
                  width: 150,
                  digits: digits,
                  caption: '已暂停',
                  paused: true,
                  animateDigits: true,
                  digitIdentity: 'same-session',
                ),
              ),
            ),
          );
          await show('25:00');
          await show('25:01');
          await tester.pump(const Duration(milliseconds: 70));
          final readouts = tester
              .widgetList<RollingDigits>(find.byType(RollingDigits))
              .toList();
          expect(readouts.first.metrics.style.fontFamily, 'Ahem');
          expect(readouts.first.metrics.style.letterSpacing, 9);
          expect(readouts.first.metrics.style.fontWeight, FontWeight.bold);
          if (theme == 'water') {
            expect(readouts.last.metrics, same(readouts.first.metrics));
          }
          await show('1:00:00');
          await pumpPresentation(tester);
          for (final readout in find.byType(RollingDigits).evaluate()) {
            final glyphs = find.descendant(
              of: find.byWidget(readout.widget),
              matching: find.byType(RichText),
            );
            expect(glyphs, findsNWidgets(7));
            for (final glyph in glyphs.evaluate()) {
              final paragraph = glyph.renderObject! as RenderParagraph;
              expect(paragraph.maxLines, 1);
              expect(paragraph.softWrap, false);
              expect(
                paragraph.getMaxIntrinsicWidth(double.infinity),
                lessThanOrEqualTo(paragraph.size.width + .01),
              );
              final glyphRect = tester.getRect(find.byWidget(glyph.widget));
              final dialRect = tester.getRect(find.byType(YikeDial));
              expect(glyphRect.left, greaterThanOrEqualTo(dialRect.left));
              expect(glyphRect.right, lessThanOrEqualTo(dialRect.right));
            }
          }
          expect(find.text('已暂停'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'list values retain right edge and descriptions retain left edge',
    (tester) async {
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 340,
            child: Column(
              children: [
                CommonListCell(
                  key: ValueKey('a'),
                  title: '专注时长',
                  value: '25 分钟',
                  navigation: true,
                ),
                CommonListCell(
                  key: ValueKey('b'),
                  title: '长休间隔',
                  value: '每 4 轮',
                  navigation: true,
                ),
                CommonListCell(
                  key: ValueKey('c'),
                  title: '已归档习惯',
                  value: '查看与恢复',
                  navigation: true,
                ),
                CommonListCell(
                  title: '归档习惯',
                  description: '保留记录，从打卡页隐藏',
                  navigation: true,
                ),
              ],
            ),
          ),
        ),
      );
      Rect arrow(String key) => tester.getRect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byWidgetPredicate(
            (w) => w is CommonIcon && w.name == CommonIconName.chevronRight,
          ),
        ),
      );
      expect(arrow('a').right, closeTo(arrow('b').right, .01));
      expect(arrow('a').right, closeTo(arrow('c').right, .01));
      final ts = TS.of(tester.element(find.byKey(const ValueKey('a'))));
      expect(
        arrow('a').right,
        closeTo(
          tester.getRect(find.byKey(const ValueKey('a'))).right - ts.spacing.md,
          .01,
        ),
      );
      expect(
        tester.getTopLeft(find.text('归档习惯')).dx,
        tester.getTopLeft(find.text('保留记录，从打卡页隐藏')).dx,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'water fill clips full-size artwork instead of shrinking rounded corners',
    (tester) async {
      final ts = TS(
        brightness: Brightness.light,
        pack: generatedThemePacks.firstWhere((p) => p.id == 'yike/water'),
      );
      for (final progress in [.3, .6, .9]) {
        await tester.pumpWidget(
          shell(
            Center(
              child: YikeDial(tokens: ts, width: 200, progress: progress),
            ),
          ),
        );
        final fill = find.byKey(const ValueKey('water-fill'));
        final size = tester.getSize(fill);
        final image = find.descendant(of: fill, matching: find.byType(Image));
        expect(tester.getSize(image), size);
        final clip = tester.widget<ClipPath>(fill).clipper!.getClip(size);
        final waterline = size.height * (1 - progress);
        expect(clip.contains(Offset(2, waterline + 2)), true);
        expect(clip.contains(Offset(size.width - 2, waterline + 2)), true);
        expect(clip.contains(Offset(size.width / 2, waterline - 2)), false);
      }
    },
  );

  testWidgets(
    'pages slide without fading and reverse from existing positions',
    (tester) async {
      String? tapped;
      Future<void> show(int value, {bool reduced = false}) => tester.pumpWidget(
        shell(
          SizedBox(
            width: 300,
            child: MotionPage<int>(
              value: value,
              direction: (before, after) => (after - before).sign.toDouble(),
              child: SizedBox(
                key: ValueKey('page-$value'),
                width: 300,
                height: 80,
                child: TextButton(
                  onPressed: () => tapped = '$value',
                  child: Text('内容$value'),
                ),
              ),
            ),
          ),
          reduced: reduced,
        ),
      );
      await show(0);
      await show(1);
      await tester.pump(const Duration(milliseconds: 70));
      Rect page(int value) =>
          tester.getRect(find.byKey(ValueKey('page-$value')));
      expect(page(0).right, closeTo(page(1).left, .01));
      expect(page(1).left, greaterThan(0));
      expect(
        find.descendant(
          of: find.byType(MotionPage<int>),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      expect(find.semantics.byLabel('内容0'), findsNothing);
      final before = page(0);
      await show(0);
      expect(page(0).left, closeTo(before.left, .01));
      await show(2, reduced: true);
      expect(find.byKey(const ValueKey('page-0')), findsNothing);
      expect(find.byKey(const ValueKey('page-1')), findsNothing);
      await tester.tap(find.text('内容2'));
      expect(tapped, '2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('accepted unsaved checkins and undo emit accurate feedback', (
    tester,
  ) async {
    final disk = FaultPrefs();
    final app = await pumpYike(tester, preferences: disk);
    disk.failWrite = true;
    final data = app.read(localDataProvider).data;
    expect(
      app.read(localDataProvider.notifier).commitResult(data),
      CommitResult.acceptedUnsaved,
    );
    final actions = app.read(habitsProvider.notifier);
    final added = actions.toggle('habit-water', '2026-10-16')!;
    expect(app.read(habitFeedbackProvider)!.kind, HabitFeedbackKind.added);
    expect(app.read(habitsProvider).first.dates, contains('2026-10-16'));
    final removed = actions.toggle('habit-water', '2026-10-16')!;
    expect(app.read(habitFeedbackProvider)!.kind, HabitFeedbackKind.removed);
    // Undo is only valid on the habits tab, and restoring a cancellation is not a new entrance.
    app.read(rootTabProvider.notifier).set(1);
    final cancellation = actions.toggle('habit-water', '2026-10-16')!;
    actions.toggle('habit-water', '2026-10-16');
    final ticket = app.read(habitUndoProvider)!;
    expect(actions.undo(ticket), false); // Applied in memory, still unsaved.
    expect(app.read(habitFeedbackProvider)!.kind, HabitFeedbackKind.restored);
    expect(added.token, isNot(removed.token));
    expect(cancellation.habitId, 'habit-water');
    await tester.pump();
  });

  testWidgets(
    'editor provider validates raw time and retries one draft identity',
    (tester) async {
      final disk = FaultPrefs();
      final app = await pumpYike(tester, preferences: disk);
      final editor = habitEditorProvider(null);
      final subscription = app.listen(editor, (_, _) {});
      addTearDown(subscription.close);
      final controller = app.read(editor.notifier);
      final initial = app.read(editor).draft;
      controller.change(initial.copyWith(name: '读书', reminder: true));
      controller.changeTime('25:99');
      expect(controller.submit(), false);
      expect(app.read(editor).timeError, isNotNull);
      expect(
        app.read(habitsProvider).where((h) => h.id == initial.id),
        isEmpty,
      );
      controller.changeTime('21:30');
      disk.failWrite = true;
      expect(controller.submit(), false);
      expect(
        app.read(habitsProvider).where((h) => h.id == initial.id),
        hasLength(1),
      );
      disk.failWrite = false;
      expect(controller.submit(), true);
      final saved = app
          .read(habitsProvider)
          .singleWhere((h) => h.id == initial.id);
      expect(saved.reminderMinutes, 21 * 60 + 30);
      expect(app.read(editor).draft.id, initial.id);
      expect(tester.takeException(), isNull);
    },
  );
}
