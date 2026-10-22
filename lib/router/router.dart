import 'package:flutter/material.dart';

import '../app/bootstrap_page.dart';
import 'routes.dart';

export 'routes.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.bootstrap: (_) => const BootstrapPage(),
};
