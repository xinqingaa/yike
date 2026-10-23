import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yike/app/app.dart';
import 'package:yike/app/navigation.dart';
import 'package:yike/common/widgets.dart';
import 'package:yike/features/focus/focus.dart';
import 'package:yike/features/home/pages/home_page.dart';
import 'package:yike/storage/providers.dart';
import 'package:yike/theme/ts.dart';

import '../test/support/fake_app_prefs.dart';
import '../test/support/pump_presentation.dart';

/// Run on a physical phone in profile mode. This reports Flutter frame costs,
/// not end-to-end input latency or an acceptance result for a different device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const device = String.fromEnvironment('YIKE_PROFILE_DEVICE');
  testWidgets('physical device motion frame samples', (tester) async {
    expect(
      kProfileMode,
      isTrue,
      reason: 'Run with --profile on a physical phone.',
    );
    expect(
      device,
      isNotEmpty,
      reason:
          'Supply --dart-define=YIKE_PROFILE_DEVICE=<physical device/model>.',
    );
    final timing = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timing.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);
    addTearDown(() => SchedulerBinding.instance.removeTimingsCallback(collect));
    final refresh = tester.view.display.refreshRate;
    final budget = 1000000 / refresh;
    Future<void> frames(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> sample(String scene, Future<void> Function() work) async {
      // Let prior frame timing batches drain before opening the sample window.
      await frames(125);
      timing.clear();
      await work();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      expect(timing, isNotEmpty, reason: 'No engine frame timings received.');
      Map<String, Object> distribution(List<int> values) {
        values.sort();
        double percentile(double p) =>
            values[((values.length - 1) * p).round()] / 1000;
        return {
          'p50_ms': percentile(.5),
          'p90_ms': percentile(.9),
          'p99_ms': percentile(.99),
          'over_budget': values.where((value) => value > budget).length,
        };
      }

      debugPrint(
        'YIKE_MOTION_PROFILE=${jsonEncode({'device': device, 'os': Platform.operatingSystemVersion, 'mode': 'profile', 'refresh_hz': refresh, 'warmup_frames': 125, 'scene': scene, 'samples': timing.length, 'ui': distribution(timing.map((f) => f.buildDuration.inMicroseconds).toList()), 'raster': distribution(timing.map((f) => f.rasterDuration.inMicroseconds).toList())})}',
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPrefsProvider.overrideWithValue(FakeAppPrefs())],
        child: const PbApp(),
      ),
    );
    await pumpPresentation(tester);
    final app = ProviderScope.containerOf(
      tester.element(find.byType(YikeHomePage)),
    );
    final actions = app.read(focusActionsProvider);
    actions.switchMode(TimerMode.stopwatch);
    actions.start();
    for (final theme in ['mechanical', 'water', 'sundial']) {
      app.read(themePackProvider.notifier).select('yike/$theme');
      await sample('$theme-continuous', () => frames(300));
    }
    await sample('theme-transitions', () async {
      for (var i = 0; i < 9; i++) {
        app
            .read(themePackProvider.notifier)
            .select('yike/${['mechanical', 'water', 'sundial'][i % 3]}');
        await frames(30);
      }
    });
    await sample('lap-insertion', () async {
      for (var i = 0; i < 12; i++) {
        await frames(65);
        actions.lap();
      }
    });
    await sample('root-transitions', () async {
      for (var i = 0; i < 12; i++) {
        app.read(rootTabProvider.notifier).set(i % 3);
        await frames(30);
      }
    });
    app.read(rootTabProvider.notifier).set(0);
    actions.pause();
    await pumpPresentation(tester);
    expect(find.byType(CommonBottomNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
