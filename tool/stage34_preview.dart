// Temporary acceptance entry. Delete only after the user's device acceptance.
// Uses memory preferences and sample facts; sound/haptic services are real.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yike/app/app.dart';
import 'package:yike/common/time.dart';
import 'package:yike/features/focus/focus_models.dart';
import 'package:yike/features/habits/habit_models.dart';
import 'package:yike/features/local_data/local_data.dart';
import 'package:yike/features/local_data/models/local_data_prefs.dart';
import 'package:yike/storage/providers.dart';
import '../test/support/fake_app_prefs.dart';

YikeData stage34Sample(DateTime now) {
  final today = dayOnly(now), first = today.subtract(const Duration(days: 364));
  final records = <FocusRecord>[];
  for (var i = 0; i < 180; i++) {
    if (i % 5 == 1) continue;
    final date = today.subtract(Duration(days: i));
    for (var n = 0; n < (i % 3) + 1; n++) {
      final seconds = 300 + ((i * 137 + n * 521) % 3000);
      records.add(
        FocusRecord(
          sessionId: 'preview-$i-$n',
          mode: TimerMode.values[(i + n) % 3],
          startedAt: DateTime(
            date.year,
            date.month,
            date.day,
            9 + (i + n) % 14,
          ),
          elapsedMs: seconds * 1000,
          days: {dayId(date): seconds * 1000},
        ),
      );
    }
  }
  final yesterday = today.subtract(const Duration(days: 1));
  records.add(
    FocusRecord(
      sessionId: 'preview-cross-day',
      mode: TimerMode.stopwatch,
      startedAt: DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        23,
        59,
        30,
      ),
      elapsedMs: 90000,
      days: {dayId(yesterday): 30000, dayId(today): 60000},
    ),
  );
  final habits = <HabitViewData>[];
  for (var i = 0; i < 3; i++) {
    final checkins = <String, HabitCheckin>{};
    for (var n = 0; n < 365; n++) {
      final date = first.add(Duration(days: n));
      if ((n + i) % (i + 2) == 0) {
        checkins[dayId(date)] = HabitCheckin(
          id: 'preview-habit-$i-$n',
          at: DateTime(date.year, date.month, date.day, 20 + i, 8),
        );
      }
    }
    habits.add(
      HabitViewData(
        id: 'preview-habit-$i',
        name: ['阅读', '散步', '练习吉他'][i],
        created: dayId(first),
        weekly: i == 2,
        goal: 3,
        dates: checkins.keys.toSet(),
        checkins: checkins,
      ),
    );
  }
  return YikeData(
    firstUsed: dayId(first),
    focus: FocusData(
      mode: TimerMode.stopwatch,
      records: records,
      session: FocusSession(
        id: 'preview-current',
        mode: TimerMode.stopwatch,
        stage: TimerStage.focus,
        status: TimerStatus.paused,
        startedAt: now.subtract(const Duration(seconds: 758)),
        targetMs: 0,
        elapsedMs: 758000,
        round: 1,
        longRest: false,
        days: {dayId(today): 758000},
        laps: const [
          85000,
          177000,
          257000,
          363000,
          440000,
          529000,
          614000,
          680000,
        ],
      ),
    ),
    habits: habits,
  );
}

FakeAppPrefs stage34Preferences(
  DateTime now, {
  String theme = 'mechanical',
  String mode = 'light',
}) {
  final prefs = FakeAppPrefs({'theme_pack': 'yike/$theme', 'theme_mode': mode});
  prefs.write(localDataPrefs, stage34Sample(now));
  return prefs;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const theme = String.fromEnvironment(
    'YIKE_STAGE34_THEME',
    defaultValue: 'mechanical',
  );
  const dark = bool.fromEnvironment('YIKE_STAGE34_DARK');
  const reduce = bool.fromEnvironment('YIKE_STAGE34_REDUCE');
  runApp(
    ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(
          stage34Preferences(
            DateTime.now(),
            theme: theme,
            mode: dark ? 'dark' : 'light',
          ),
        ),
      ],
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                reduce || MediaQuery.disableAnimationsOf(context),
          ),
          child: const PbApp(),
        ),
      ),
    ),
  );
}
