import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/local_data/local_data.dart';
import '../features/habits/habits.dart';
import '../features/review/review.dart';
import '../storage/preference_writer.dart';
import '../theme/ts.dart';
import 'navigation.dart';
import '../common/overlay/app_pop.dart';

bool resetYikeData(WidgetRef ref) {
  AppPop.clearToasts();
  final saved = ref.read(localDataProvider.notifier).reset();
  ref.read(habitsProvider.notifier).clearUndo();
  ref.invalidate(reviewSelectionProvider);
  ref.read(rootTabProvider.notifier).set(0);
  ref.read(themePackProvider.notifier).select('yike/mechanical');
  ref.read(themeModeProvider.notifier).setMode(ThemeMode.system);
  return saved && ref.read(preferenceWriterProvider).isEmpty;
}
