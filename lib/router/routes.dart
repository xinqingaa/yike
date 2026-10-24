/// Navigator 1.0 named route paths.
///
/// New screens: add a constant here, register in [appRoutes], and expose an
/// entry from the screen's feature flow when needed.
abstract final class AppRoutes {
  static const bootstrap = '/';
  static const home = '/home';
  static const settings = '/settings';
  static const habitDetail = '/habit';
}

/// Optional initial panel within the full settings page.
class SettingsRouteArguments {
  const SettingsRouteArguments({this.openCountdownPresets = false});
  final bool openCountdownPresets;
}
