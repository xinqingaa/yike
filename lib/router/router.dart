import 'package:flutter/material.dart';

import '../features/home/pages/home_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/habits/pages/habit_detail_page.dart';
import 'routes.dart';
import '../features/review/pages/statistics_page.dart';
import '../features/review/models/review_period.dart';
import '../features/focus/focus_models.dart';

export 'navigator_key.dart';
export 'routes.dart';

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.home: (_) => const YikeHomePage(),
  AppRoutes.settings: (context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    return YikeSettingsPage(
      openCountdownPresets:
          arguments is SettingsRouteArguments && arguments.openCountdownPresets,
    );
  },
  AppRoutes.statistics: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return StatisticsPage(
      initial: args is StatisticsRouteArguments
          ? ReviewSelection(
              anchor: args.anchor,
              month: args.month,
              mode: args.mode == null
                  ? null
                  : TimerMode.values.byName(args.mode!),
            )
          : null,
    );
  },
  AppRoutes.habitDetail: (_) => const HabitDetailPage(),
};
