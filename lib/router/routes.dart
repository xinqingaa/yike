/// Navigator 1.0 named route paths.
///
/// New screens: add a constant here, register in [appRoutes], and expose an
/// entry from the screen's feature flow when needed.
abstract final class AppRoutes {
  static const home = '/home';
  static const settings = '/settings';
  static const habitDetail = '/habit';
  static const statistics = '/statistics';
}

/// Optional initial panel within the full settings page.
class SettingsRouteArguments {
  const SettingsRouteArguments({this.openCountdownPresets = false});
  final bool openCountdownPresets;
}

class StatisticsRouteArguments {
  const StatisticsRouteArguments({
    required this.anchor,
    this.month = false,
    this.mode,
  });
  final DateTime anchor;
  final bool month;
  final String? mode;
}
