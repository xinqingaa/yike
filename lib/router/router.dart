import 'package:flutter/material.dart';

import '../app/bootstrap_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/habits/pages/habit_detail_page.dart';
import 'routes.dart';

export 'navigator_key.dart';
export 'routes.dart';

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.bootstrap: (_) => const BootstrapPage(),
  AppRoutes.home: (_) => const YikeHomePage(),
  AppRoutes.settings: (_) => const YikeSettingsPage(),
  AppRoutes.habitDetail: (_) => const HabitDetailPage(),
};
