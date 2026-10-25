import 'package:flutter/widgets.dart';

/// Synchronous route facts for application side effects, including before build.
class AppRouteActivity extends NavigatorObserver with ChangeNotifier {
  String? current;
  void _changed(Route<dynamic>? route) {
    current = route?.settings.name;
    notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _changed(newRoute);
}

final appRouteActivity = AppRouteActivity();
