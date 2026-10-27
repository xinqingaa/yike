import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'dart:async';
import 'package:yike/storage/app_prefs.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yike/app/app.dart';
import 'package:yike/app/timer_status_progress.dart';
import 'package:yike/common/overlay/sheet_header.dart';
import 'package:yike/router/router.dart';
import 'package:yike/theme/ts.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/app/notifications/notification_plan.dart';
import 'package:yike/app/notifications/notification_coordinator.dart';
import 'package:yike/common/clock.dart';
import 'package:yike/common/notifications/notification_models.dart';
import 'package:yike/common/notifications/notification_adapter.dart';
import 'package:yike/common/notifications/notification_metadata.dart';
import 'package:yike/common/overlay/popup_activity.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/focus/focus_models.dart';
import 'package:yike/features/focus/providers/focus_dial_presentation.dart';
import 'package:yike/features/habits/habit_models.dart';
import 'package:yike/features/habits/pages/habit_editor.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/storage/providers.dart';
import 'support/fake_app_prefs.dart';
import 'support/pump_presentation.dart';
import 'support/fake_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime(2026, 10, 24, 12);
  FocusData parallel() {
    var d = const FocusData(
      preferences: TimingPreferences(focusSeconds: 5, threshold: 1),
    );
    for (final mode in TimerMode.values) {
      d = d.copyWith(mode: mode, countdown: 5);
      d = FocusEngine.start(d, start, mode.name);
    }
    return d;
  }

  test(
    'parallel calibration, pause, discard and recovery isolate each slot',
    () {
      var d = parallel();
      d = FocusEngine.pause(
        d.copyWith(mode: TimerMode.stopwatch),
        start.add(const Duration(seconds: 2)),
      );
      d = FocusEngine.advance(d, start.add(const Duration(seconds: 5)));
      expect(d.sessionFor(TimerMode.stopwatch)!.elapsedMs, 2000);
      expect(d.sessionFor(TimerMode.pomodoro)!.status, TimerStatus.finished);
      expect(d.sessionFor(TimerMode.countdown)!.status, TimerStatus.finished);
      expect(d.records, hasLength(2));
      expect(d.cycles, 1);
      expect(
        FocusEngine.advance(d, start.add(const Duration(seconds: 6))).records,
        hasLength(2),
      );
      d = FocusEngine.leave(d.copyWith(mode: TimerMode.countdown));
      expect(d.allSessions, hasLength(2));
      expect(d.sessionFor(TimerMode.pomodoro)!.status, TimerStatus.finished);
      final recovered = FocusEngine.recover(parallel());
      expect(
        recovered.allSessions.values.every(
          (s) => s.recovered && s.status == TimerStatus.paused,
        ),
        isTrue,
      );
    },
  );
  test(
    'all three completions are synchronous, distinct and never replayed by retry',
    () {
      var now = start;
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(app.dispose);
      final events = <FocusCompletion>[];
      final sub = app.read(focusCompletionEventsProvider).listen(events.add);
      addTearDown(sub.cancel);
      final sessions = {
        for (final mode in TimerMode.values)
          mode: FocusSession(
            id: mode.name,
            mode: mode,
            stage: TimerStage.focus,
            status: TimerStatus.running,
            startedAt: start,
            anchor: start,
            targetMs: mode == TimerMode.stopwatch ? 0 : 3599000,
            round: 1,
            longRest: false,
          ),
      };
      final controller = app.read(localDataProvider.notifier);
      controller.commit(
        app
            .read(localDataProvider)
            .data
            .copyWith(focus: FocusData(sessions: sessions)),
      );
      now = start.add(const Duration(seconds: 3599));
      controller.advance(now);
      expect(events.map((e) => e.mode).toSet(), TimerMode.values.toSet());
      expect(app.read(localDataProvider).data.focus.records, hasLength(3));
      controller.retry();
      expect(events, hasLength(3));
    },
  );
  test(
    'new format round-trips all slots and rejects duplicates and version 2',
    () {
      final data = YikeData.initial(
        start,
      ).copyWith(focus: parallel(), backgroundReminders: true);
      final raw = localDataPrefs.codec.encode(data);
      final read = localDataPrefs.codec.decode(raw);
      expect(read.focus.allSessions, hasLength(3));
      expect(read.backgroundReminders, isTrue);
      final broken = jsonDecode(raw) as Map<String, dynamic>;
      broken['schemaVersion'] = 2;
      expect(
        () => localDataPrefs.codec.decode(jsonEncode(broken)),
        throwsA(isA<UnsupportedPrefsVersion>()),
      );
      broken['schemaVersion'] = 4;
      final slots = broken['data']['focus']['sessions'] as List;
      slots.add(slots.first);
      expect(
        () => localDataPrefs.codec.decode(jsonEncode(broken)),
        throwsFormatException,
      );
    },
  );
  test(
    'hidden running pomodoro freezes rest arrangement across configuration edits',
    () {
      var d = FocusEngine.start(
        const FocusData(
          preferences: TimingPreferences(
            focusSeconds: 1,
            shortSeconds: 12,
            longSeconds: 60,
            threshold: 1,
          ),
        ),
        start,
        'focus',
      );
      d = d.copyWith(
        mode: TimerMode.countdown,
        preferences: d.preferences.copyWith(shortSeconds: 59, longSeconds: 300),
      );
      d = FocusEngine.advance(d, start.add(const Duration(seconds: 1)));
      d = FocusEngine.beginBreak(
        d.copyWith(mode: TimerMode.pomodoro),
        start.add(const Duration(seconds: 1)),
        'rest',
      );
      expect(d.session!.targetMs, 12000);
    },
  );
  test(
    'calendar budget reserves timers and sorts dates globally with per-habit coverage',
    () {
      final metadata = NotificationMetadata();
      final data = YikeData.initial(start).copyWith(
        focus: parallel(),
        backgroundReminders: true,
        habits: [
          for (var i = 0; i < 70; i++)
            HabitViewData(
              id: 'h$i',
              name: '习惯$i',
              created: '2026-10-24',
              reminder: true,
              reminderMinutes: 721,
            ),
        ],
      );
      final plan = notificationPlan(data, start, metadata, 'yike/water');
      expect(plan.where((r) => r.timer), hasLength(3));
      expect(plan.where((r) => !r.timer), hasLength(60));
      expect(
        plan.where((r) => !r.timer).every((r) => r.target.date == '2026-10-24'),
        isTrue,
      );
      expect(plan.map((r) => r.id).toSet(), hasLength(plan.length));
      final later = notificationPlan(
        data,
        start.add(const Duration(seconds: 1)),
        metadata,
        'yike/water',
      );
      expect(
        later.where((r) => r.timer).map((r) => r.at),
        plan.where((r) => r.timer).map((r) => r.at),
      );
    },
  );
  test(
    'checkin, archive, consumed dates and past times exclude habit schedules',
    () {
      final base = HabitViewData(
        id: 'h',
        name: '阅读',
        created: '2026-10-24',
        reminder: true,
        reminderMinutes: 721,
      );
      final metadata = NotificationMetadata(consumed: {'habit/h/2026-10-24'});
      final data = YikeData.initial(
        start,
      ).copyWith(backgroundReminders: true, habits: [base]);
      expect(
        notificationPlan(data, start, metadata, 'yike/water').first.target.date,
        '2026-10-25',
      );
      expect(
        notificationPlan(
          data,
          start.add(const Duration(minutes: 2)),
          NotificationMetadata(),
          'yike/water',
        ).first.target.date,
        '2026-10-25',
      );
      expect(
        notificationPlan(
          data.copyWith(habits: [base.copyWith(archivedOn: '2026-10-24')]),
          start,
          metadata,
          'yike/water',
        ),
        isEmpty,
      );
      expect(
        notificationPlan(
          data.copyWith(backgroundReminders: false),
          start,
          metadata,
          'yike/water',
        ),
        isEmpty,
      );
    },
  );
  test(
    'coordinator cancels only pending on switch-off and preserves habit settings',
    () async {
      final native = FakeNotifications();
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(native),
          clockProvider.overrideWithValue(() => start),
        ],
      );
      addTearDown(app.dispose);
      app.read(notificationCoordinatorProvider);
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final controller = app.read(localDataProvider.notifier);
      controller.commit(
        app
            .read(localDataProvider)
            .data
            .copyWith(
              backgroundReminders: true,
              habits: [
                const HabitViewData(
                  id: 'h',
                  name: '阅读',
                  created: '2026-10-24',
                  reminder: true,
                  reminderMinutes: 721,
                ),
              ],
            ),
      );
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(native.requests, hasLength(60));
      native.delivered.add(99);
      await app
          .read(notificationCoordinatorProvider.notifier)
          .setEnabled(false);
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(native.requests, isEmpty);
      expect(native.delivered, {99});
      expect(app.read(localDataProvider).data.habits.single.reminder, isTrue);
    },
  );
  Future<void> flush() async {
    for (var i = 0; i < 16; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'latest intent cancels an in-flight old schedule and reset clears delivered',
    () async {
      final native = FakeNotifications();
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(native),
          clockProvider.overrideWithValue(() => start),
        ],
      );
      addTearDown(app.dispose);
      final coordinator = app.read(notificationCoordinatorProvider.notifier);
      await flush();
      native.scheduleGate = Completer<void>();
      final controller = app.read(localDataProvider.notifier);
      controller.commit(
        app
            .read(localDataProvider)
            .data
            .copyWith(backgroundReminders: true, focus: parallel()),
      );
      await flush();
      expect(native.scheduleStarted, isTrue);
      await coordinator.setEnabled(false);
      native.scheduleGate!.complete();
      await flush();
      expect(native.requests, isEmpty);
      expect(app.read(notificationCoordinatorProvider).coverage, isEmpty);
      native.delivered.add(999);
      await coordinator.reset();
      await flush();
      expect(native.delivered, isEmpty);
      expect(native.requests, isEmpty);
    },
  );

  test(
    'habit edits, checkin and deletion reconcile pending and delivered; failures can retry',
    () async {
      final native = FakeNotifications();
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(native),
          clockProvider.overrideWithValue(() => start),
        ],
      );
      addTearDown(app.dispose);
      final coordinator = app.read(notificationCoordinatorProvider.notifier);
      await flush();
      final controller = app.read(localDataProvider.notifier);
      const habit = HabitViewData(
        id: 'h',
        name: '阅读',
        created: '2026-10-24',
        reminder: true,
        reminderMinutes: 721,
      );
      void setHabit(HabitViewData h) => controller.commit(
        app
            .read(localDataProvider)
            .data
            .copyWith(backgroundReminders: true, habits: [h]),
      );
      setHabit(habit);
      await flush();
      final first = native.requests.values.first;
      native.delivered.add(first.id);
      setHabit(habit.copyWith(name: '每日阅读', reminderMinutes: 722));
      await flush();
      expect(native.requests[first.id]!.title, '每日阅读');
      expect(native.requests[first.id]!.at.minute, 2);
      setHabit(habit.copyWith(dates: {'2026-10-24'}));
      await flush();
      expect(
        native.requests.values.any((r) => r.target.date == '2026-10-24'),
        isFalse,
      );
      controller.commit(app.read(localDataProvider).data.copyWith(habits: []));
      await flush();
      expect(native.requests, isEmpty);
      expect(native.delivered, isEmpty);
      native.fail = true;
      setHabit(habit);
      await flush();
      expect(app.read(notificationCoordinatorProvider).error, isNotNull);
      expect(app.read(notificationCoordinatorProvider).coverage, isEmpty);
      native.fail = false;
      await coordinator.refresh();
      await flush();
      expect(app.read(notificationCoordinatorProvider).error, isNull);
      expect(native.requests, hasLength(60));
    },
  );

  testWidgets(
    'foreground habit group ignores backend permission, expires and consumes skipped modal opportunities',
    (tester) async {
      var now = start;
      final native = FakeNotifications()
        ..permission = const NotificationAccess();
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(native),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: app, child: const PbApp()),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final controller = app.read(localDataProvider.notifier);
      controller.commit(
        app
            .read(localDataProvider)
            .data
            .copyWith(
              habits: [
                for (var i = 0; i < 3; i++)
                  HabitViewData(
                    id: 'h$i',
                    name: ['阅读', '喝水', '散步'][i],
                    created: '2026-10-24',
                    reminder: true,
                    reminderMinutes: 721,
                  ),
              ],
            ),
      );
      final coordinator = app.read(notificationCoordinatorProvider.notifier);
      coordinator.sample(start);
      now = start.add(const Duration(minutes: 1));
      coordinator.sample(now);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('阅读、喝水等 3 个习惯待完成'), findsOneWidget);
      expect(native.requests, isEmpty);
      await tester.tap(find.text('查看'));
      await tester.pump();
      await tester.pump();
      expect(app.read(rootTabProvider), 1);
      expect(app.read(habitReminderTargetsProvider), {'h0', 'h1', 'h2'});
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('阅读、喝水等 3 个习惯待完成'), findsNothing);
      coordinator.sample(start);
      coordinator.sample(now);
      await tester.pump();
      expect(find.text('阅读、喝水等 3 个习惯待完成'), findsNothing);
      final closed = Completer<void>();
      final modal = app
          .read(popupActivityProvider.notifier)
          .track(() => closed.future);
      controller.commit(
        app
            .read(localDataProvider)
            .data
            .copyWith(
              habits: [
                const HabitViewData(
                  id: 'skip',
                  name: '模态跳过',
                  created: '2026-10-24',
                  reminder: true,
                  reminderMinutes: 722,
                ),
              ],
            ),
      );
      coordinator.sample(now);
      now = start.add(const Duration(minutes: 2));
      coordinator.sample(now);
      closed.complete();
      await modal;
      coordinator.sample(start.add(const Duration(minutes: 1)));
      coordinator.sample(now);
      await tester.pump();
      expect(find.text('模态跳过 · 今日尚未完成'), findsNothing);
      final metadata = app
          .read(appPrefsProvider)
          .read(notificationMetadataPrefs)!;
      expect(metadata.consumed, contains('habit/skip/2026-10-24'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'parallel previews filter the selected mode and disappear behind nested modals',
    (tester) async {
      var now = start;
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(FakeNotifications()),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: app, child: const PbApp()),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final actions = app.read(focusActionsProvider);
      actions.configure(
        const TimingPreferences(
          focusSeconds: 2,
          threshold: 1,
          presets: [2, 3, 5, 8],
        ),
      );
      for (final mode in TimerMode.values) {
        actions.switchMode(mode);
        actions.start();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byTooltip('暂停番茄钟'), findsOneWidget);
      expect(find.byTooltip('暂停正计时'), findsOneWidget);
      expect(find.byTooltip('暂停倒计时'), findsNothing);
      app.read(rootTabProvider.notifier).set(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byTooltip('暂停倒计时'), findsOneWidget);
      // A modal boundary stays active until both actual dismissal futures finish.
      final outer = Completer<void>(), inner = Completer<void>();
      final activity = app.read(popupActivityProvider.notifier);
      final a = activity.track(() => outer.future),
          b = activity.track(() => inner.future);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getSize(find.byType(Navigator).first).height,
        greaterThan(0),
      );
      outer.complete();
      await a;
      expect(app.read(popupActivityProvider), 1);
      inner.complete();
      await b;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      now = now.add(const Duration(seconds: 5));
      app.read(clockPulseProvider.notifier).refresh();
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is TimerStatusProgress && w.completed),
        findsNWidgets(2),
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is TimerStatusProgress && w.completed),
        findsNothing,
      );
      expect(
        app.read(focusDataProvider).sessionFor(TimerMode.countdown)!.status,
        TimerStatus.finished,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    },
  );
  testWidgets(
    'floating timers keep page position, collapse by swipe and retain the capsule for new sessions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = start;
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(FakeNotifications()),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: app, child: const PbApp()),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final anchor = find.textContaining('今天已专注');
      final position = tester.getTopLeft(anchor);
      final actions = app.read(focusActionsProvider);
      actions.start();
      actions.switchMode(TimerMode.stopwatch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getTopLeft(anchor), position);
      await pumpPresentation(tester);
      expect(find.byTooltip('暂停番茄钟').hitTestable(), findsOneWidget);
      final surface = find.byKey(const ValueKey('timer-status-surface'));
      final expandedWidth = tester.getSize(surface).width;
      final handle = find.byKey(const ValueKey('timer-status-drag-handle'));
      await tester.drag(handle, const Offset(0, -110));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final capsule = find.byKey(const ValueKey('timer-status-capsule'));
      expect(tester.getSize(capsule).width, lessThan(expandedWidth / 2));
      expect(find.byTooltip('暂停番茄钟').hitTestable(), findsNothing);
      expect(find.byTooltip('设置').hitTestable(), findsOneWidget);
      actions.start();
      actions.switchMode(TimerMode.countdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.descendant(of: capsule, matching: find.text('2')),
        findsOneWidget,
      );
      expect(tester.getSize(capsule).width, lessThan(expandedWidth / 2));
      expect(tester.getTopLeft(anchor), position);
      await tester.tap(capsule);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('暂停番茄钟'));
      await tester.pump();
      expect(app.read(focusDataProvider).mode, TimerMode.countdown);
      expect(
        app.read(focusDataProvider).sessionFor(TimerMode.pomodoro)!.status,
        TimerStatus.paused,
      );
      expect(find.byTooltip('继续番茄钟'), findsOneWidget);
      expect(find.text('已暂停'), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('timer-status-pomodoro')))
            .height,
        lessThanOrEqualTo(50),
      );
      expect(tester.getTopLeft(anchor), position);
      // Accessibility changes during the fold must settle without restarting it.
      await tester.drag(surface, const Offset(0, -110));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(capsule);
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('继续番茄钟').hitTestable(), findsOneWidget);
      await tester.drag(surface, const Offset(0, -110));
      await tester.pump();
      now = start.add(const Duration(hours: 1));
      app.read(clockPulseProvider.notifier).refresh();
      await pumpPresentation(tester);
      expect(
        app.read(focusDataProvider).sessionFor(TimerMode.stopwatch)!.status,
        TimerStatus.finished,
      );
      await tester.tap(capsule);
      await pumpPresentation(tester);
      expect(
        find.byKey(const ValueKey('timer-status-stopwatch')),
        findsNothing,
      );
      expect(find.byTooltip('继续番茄钟').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'notification sheet stays half height and lists habits directly without a leading icon',
    (tester) async {
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(FakeNotifications()),
          clockProvider.overrideWithValue(() => start),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: app, child: const PbApp()),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      app
          .read(localDataProvider.notifier)
          .commit(
            app
                .read(localDataProvider)
                .data
                .copyWith(
                  habits: [
                    const HabitViewData(
                      id: 'read',
                      name: '阅读提醒',
                      created: '2026-10-24',
                      reminder: true,
                      reminderMinutes: 721,
                    ),
                    for (var i = 0; i < 12; i++)
                      HabitViewData(
                        id: 'off$i',
                        name: '未开启的习惯$i',
                        created: '2026-10-24',
                      ),
                  ],
                ),
          );
      appNavigatorKey.currentState!.pushNamed(AppRoutes.settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await Scrollable.ensureVisible(
        tester.element(find.text('通知提醒')),
        alignment: .3,
      );
      await pumpPresentation(tester);
      await tester.tap(find.text('通知提醒'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppSheetHeader), findsNothing);
      final viewport = find.byKey(
        const ValueKey('notification-settings-content'),
      );
      final rect = tester.getRect(viewport);
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(rect.height, lessThanOrEqualTo(screenHeight * .5));
      expect(rect.height, greaterThan(screenHeight * .3));
      expect(find.text('阅读提醒'), findsOneWidget);
      expect(find.text('未开启的习惯0'), findsOneWidget);
      final toggle = find.widgetWithText(CommonListCell, '后台提醒');
      expect(tester.widget<CommonListCell>(toggle).leading, isNull);
      await tester.tap(find.text('后台提醒'));
      await pumpPresentation(tester);
      expect(app.read(localDataProvider).data.backgroundReminders, isTrue);
      expect(tester.getRect(viewport), rect);
      expect(find.textContaining('2026-10-24 —'), findsOneWidget);
      await tester.drag(viewport, const Offset(0, -500));
      await pumpPresentation(tester);
      expect(tester.getRect(viewport), rect);
      await tester.ensureVisible(find.text('未开启的习惯10'));
      await pumpPresentation(tester);
      expect(find.text('未开启的习惯10').hitTestable(), findsOneWidget);
      expect(tester.getRect(viewport), rect);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    },
  );
  testWidgets(
    'floating rows fit narrow large text across themes and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(FakeNotifications()),
          clockProvider.overrideWithValue(() => start),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: app, child: const PbApp()),
      );
      await pumpPresentation(tester);
      final actions = app.read(focusActionsProvider);
      for (final mode in TimerMode.values) {
        actions.switchMode(mode);
        actions.start();
      }
      app.read(rootTabProvider.notifier).set(1);
      for (final theme in ['yike/mechanical', 'yike/water', 'yike/sundial']) {
        app.read(themePackProvider.notifier).select(theme);
        await pumpPresentation(tester);
        expect(find.byTooltip('暂停番茄钟').hitTestable(), findsOneWidget);
        expect(find.byTooltip('暂停正计时').hitTestable(), findsOneWidget);
        expect(find.byTooltip('暂停倒计时').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    },
  );
  testWidgets(
    'habit time wheels keep changes in the draft until Save and discard cancelled edits',
    (tester) async {
      final app = ProviderContainer(
        overrides: [
          appPrefsProvider.overrideWithValue(returningAppPrefs()),
          notificationAdapterProvider.overrideWithValue(FakeNotifications()),
          clockProvider.overrideWithValue(() => start),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(container: app, child: const PbApp()),
      );
      await pumpPresentation(tester);
      const habit = HabitViewData(
        id: 'time',
        name: '阅读',
        created: '2026-10-24',
        reminder: true,
        reminderMinutes: 1290,
      );
      app
          .read(localDataProvider.notifier)
          .commit(app.read(localDataProvider).data.copyWith(habits: [habit]));
      final first = openHabitEditor(habit: habit);
      await pumpPresentation(tester);
      final picker = find.byKey(const ValueKey('habit-reminder-time'));
      await tester.ensureVisible(picker);
      await pumpPresentation(tester);
      expect(
        find.descendant(of: picker, matching: find.byType(EditableText)),
        findsNothing,
      );
      var wheel = tester.widget<CommonWheelPicker>(picker);
      expect(wheel.values, [21, 30]);
      expect(wheel.columns.map((c) => c.options.length), [24, 60]);
      await tester.drag(
        find
            .descendant(of: picker, matching: find.byType(ListWheelScrollView))
            .first,
        const Offset(0, -48),
      );
      await pumpPresentation(tester);
      expect(tester.widget<CommonWheelPicker>(picker).values.first, isNot(21));
      expect(
        app.read(localDataProvider).data.habits.single.reminderMinutes,
        1290,
      );
      await tester.binding.handlePopRoute();
      await pumpPresentation(tester);
      await first;
      final second = openHabitEditor(habit: habit);
      await pumpPresentation(tester);
      await tester.ensureVisible(picker);
      await pumpPresentation(tester);
      expect(tester.widget<CommonWheelPicker>(picker).values, [21, 30]);
      await tester.drag(
        find
            .descendant(of: picker, matching: find.byType(ListWheelScrollView))
            .last,
        const Offset(0, -48),
      );
      await pumpPresentation(tester);
      wheel = tester.widget<CommonWheelPicker>(picker);
      final selected = (wheel.values[0] as int) * 60 + (wheel.values[1] as int);
      expect(selected, isNot(1290));
      await tester.tap(find.byKey(const ValueKey('habit-save')));
      await pumpPresentation(tester);
      expect(await second, true);
      expect(
        app.read(localDataProvider).data.habits.single.reminderMinutes,
        selected,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    },
  );
}
