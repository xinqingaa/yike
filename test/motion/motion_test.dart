import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/motion/content_transition.dart';
import 'package:yike/common/motion/motion_list.dart';
import 'package:yike/common/motion/rolling_digits.dart';
import 'package:yike/common/widgets/yike/dial.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/focus_models.dart';
import 'package:yike/features/focus/logic/focus_projection.dart';
import 'package:yike/features/habits/habits.dart';
import 'package:yike/theme/ts.dart';
import '../support/pump_presentation.dart';
import '../yike_ui_test.dart' show pumpYike, navigateTab;

Widget shell(Widget child, {bool reduced = false}) => MaterialApp(
  theme: TS(
    brightness: Brightness.light,
    pack: generatedThemePacks.first,
  ).toThemeData(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

void main() {
  test('stopwatch projection caps at 59:59 without hour wrapping', () {
    final now = DateTime.utc(2026, 10, 23);
    final session = FocusSession(
      id: 'hour',
      mode: TimerMode.stopwatch,
      stage: TimerStage.focus,
      status: TimerStatus.running,
      startedAt: now,
      anchor: now,
      targetMs: 0,
      round: 1,
      longRest: false,
    );
    FocusProjection at(int milliseconds) => FocusProjection.at(
      session,
      const FocusViewData(mode: TimerMode.stopwatch),
      now.add(Duration(milliseconds: milliseconds)),
    );
    expect(at(3599999).seconds, 3599);
    expect(at(3600005).progress, 3599 / 3600);
    expect(at(3600650).progress, 3599 / 3600);
    expect(at(3600800).progress, 3599 / 3600);
    expect(at(3600800).seconds, 3599);
    expect(at(7200050).progress, 3599 / 3600);
  });

  testWidgets(
    'replacement excludes outgoing input and semantics; reversal keeps latest',
    (tester) async {
      String? tapped;
      Future<void> show(String value, {bool reduced = false}) =>
          tester.pumpWidget(
            shell(
              MotionContent(
                identity: value,
                direction: 1,
                child: TextButton(
                  onPressed: () => tapped = value,
                  child: Text(value),
                ),
              ),
              reduced: reduced,
            ),
          );
      await show('甲');
      await show('乙');
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('甲'), findsOneWidget);
      expect(find.semantics.byLabel('甲'), findsNothing);
      await tester.tap(find.text('甲'), warnIfMissed: false);
      expect(tapped, isNot('甲'));
      await show('丙');
      await tester.pump(const Duration(milliseconds: 35));
      await show('乙', reduced: true);
      expect(find.text('丙'), findsNothing);
      expect(find.text('甲'), findsNothing);
      await tester.tap(find.text('乙'));
      expect(tapped, '乙');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expand preserves draft through reduced motion and removes collapsed focus',
    (tester) async {
      final controller = TextEditingController(text: '草稿');
      addTearDown(controller.dispose);
      Future<void> show(bool open, bool reduced) => tester.pumpWidget(
        shell(
          Column(
            children: [
              MotionExpand(
                expanded: open,
                child: TextField(controller: controller),
              ),
            ],
          ),
          reduced: reduced,
        ),
      );
      await show(true, false);
      final state = tester.state(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await show(false, false);
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      await show(true, true);
      expect(tester.state(find.byType(TextField)), same(state));
      expect(controller.text, '草稿');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list inserts locally, keeps unaffected row identity and scroll',
    (tester) async {
      Widget rows(List<int> values) => shell(
        SizedBox(
          height: 240,
          child: MotionList<int>(
            items: values,
            identity: (n) => n,
            itemBuilder: (_, n) => SizedBox(
              key: ValueKey('row-$n'),
              height: 60,
              child: TextField(key: ValueKey('field-$n')),
            ),
          ),
        ),
      );
      await tester.pumpWidget(rows([1, 2, 3, 4, 5, 6]));
      await tester.enterText(find.byKey(const ValueKey('field-2')), '保留');
      final row = tester.state(find.byKey(const ValueKey('field-2')));
      final before = tester.getTopLeft(find.byKey(const ValueKey('row-2'))).dy;
      await tester.pumpWidget(rows([0, 1, 2, 3, 4, 5, 6]));
      await tester.pump(const Duration(milliseconds: 70));
      final middle = tester.getTopLeft(find.byKey(const ValueKey('row-2'))).dy;
      expect(middle, greaterThan(before));
      expect(middle, lessThan(before + 60));
      await pumpPresentation(tester);
      expect(tester.state(find.byKey(const ValueKey('field-2'))), same(row));
      expect(find.text('保留'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await pumpPresentation(tester);
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await tester.pumpWidget(rows([0, 1, 2, 3, 4, 5, 6, 7]));
      await pumpPresentation(tester);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        scroll,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changing reduced motion preserves the current content scroll', (
    tester,
  ) async {
    Widget body(bool reduced) => shell(
      MotionContent(
        identity: 'same-day',
        resize: false,
        child: ListView(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('记录 $i')),
          ],
        ),
      ),
      reduced: reduced,
    );
    await tester.pumpWidget(body(false));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await pumpPresentation(tester);
    final state = tester.state<ScrollableState>(find.byType(Scrollable));
    final offset = state.position.pixels;
    await tester.pumpWidget(body(true));
    expect(tester.state<ScrollableState>(find.byType(Scrollable)), same(state));
    expect(state.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  for (final theme in ['mechanical', 'water', 'sundial']) {
    testWidgets(
      '$theme dial isolates frames, rolls only adjacent seconds, freezes pause',
      (tester) async {
        var now = DateTime.utc(2026, 10, 16, 12);
        final app = await pumpYike(tester, theme: theme, clock: () => now);
        final actions = app.read(focusActionsProvider);
        actions.switchMode(TimerMode.stopwatch);
        await pumpPresentation(tester);
        actions.start();
        await tester.pump();
        final initial = tester.widget<YikeDial>(find.byType(YikeDial).first);
        final progress = initial.frame!.value.progress;
        now = now.add(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.widget<YikeDial>(find.byType(YikeDial).first),
          same(initial),
        );
        expect(initial.frame!.value.progress, greaterThan(progress));
        now = now.add(const Duration(milliseconds: 58900));
        await tester.pump(const Duration(milliseconds: 16));
        await pumpPresentation(tester);
        final metrics = tester
            .widget<RollingDigits>(find.byType(RollingDigits).first)
            .metrics;
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 50));
        final digits = tester
            .widgetList<RollingDigits>(find.byType(RollingDigits))
            .toList();
        expect(digits.first.value, '01:00');
        expect(digits.first.phase, inExclusiveRange(0, 1));
        expect(digits.first.metrics, same(metrics));
        if (theme == 'water') {
          expect(digits, hasLength(2));
          expect(digits.last.phase, digits.first.phase);
          expect(digits.last.metrics, same(digits.first.metrics));
        }
        actions.pause();
        await tester.pump();
        final paused = tester.widget<YikeDial>(find.byType(YikeDial).first);
        final frozen = paused.frame!.value.progress;
        expect(
          tester.widget<RollingDigits>(find.byType(RollingDigits).first).phase,
          1,
        );
        now = now.add(const Duration(seconds: 3));
        await pumpPresentation(tester);
        expect(paused.frame!.value.progress, frozen);
        expect(paused.frame!.value.beat, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$theme 59:59 limit stays readable on a narrow large-text dial',
      (tester) async {
        var now = DateTime.utc(2026, 10, 16, 12);
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        final app = await pumpYike(
          tester,
          theme: theme,
          clock: () => now,
          size: const Size(320, 640),
          focus: const FocusViewData(
            mode: TimerMode.stopwatch,
            status: TimerStatus.running,
            seconds: 3598,
            target: 0,
          ),
        );
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 16));
        final readout = tester.widget<RollingDigits>(
          find.byType(RollingDigits).first,
        );
        expect(readout.value, '59:59');
        expect(readout.phase, inInclusiveRange(0, 1));
        expect(
          tester
              .widget<YikeDial>(find.byType(YikeDial).first)
              .frame!
              .value
              .progress,
          3599 / 3600,
        );
        app.read(focusActionsProvider).pause();
        await pumpPresentation(tester);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$theme new checkin feedback cancels and replays only on new operations',
      (tester) async {
        final app = await pumpYike(tester, theme: theme);
        await navigateTab(tester, '打卡');
        final target = find.byKey(const ValueKey('check-habit-water'));
        double scale() => tester
            .widget<Transform>(
              find.descendant(
                of: find.byKey(const ValueKey('feedback-habit-water')),
                matching: find.byKey(const ValueKey('checkin-feedback-motion')),
              ),
            )
            .transform
            .storage[0];
        app.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(scale(), 1);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(scale(), lessThan(1));
        await tester.tap(target);
        await tester.pump();
        expect(app.read(habitsProvider).first.dates, isEmpty);
        await tester.pump(const Duration(milliseconds: 180));
        expect(scale(), 1);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(scale(), lessThan(1));
        await pumpPresentation(tester);
        await navigateTab(tester, '回顾');
        await navigateTab(tester, '打卡');
        expect(scale(), 1);
        app.read(habitsProvider.notifier).replace([
          for (final habit in app.read(habitsProvider))
            if (habit.id == 'habit-water')
              habit.copyWith(dates: {}, checkins: {})
            else
              habit,
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(scale(), 1);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.text('撤销'));
        await tester.pump();
        expect(app.read(habitsProvider).first.dates, isEmpty);
        await tester.pump(const Duration(milliseconds: 180));
        expect(scale(), 1);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(scale(), lessThan(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
