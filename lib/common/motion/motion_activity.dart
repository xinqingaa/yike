import 'package:flutter/material.dart';

final motionRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Combines route, application and selected-panel visibility for local motion.
class MotionVisibility extends StatefulWidget {
  const MotionVisibility({super.key, required this.child});
  final Widget child;
  @override
  State<MotionVisibility> createState() => _MotionVisibilityState();
}

class _MotionVisibilityState extends State<MotionVisibility> with RouteAware {
  ModalRoute<dynamic>? _route;
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        setState(() => _foreground = state == AppLifecycleState.resumed);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      if (_route != null) motionRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) motionRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => setState(() {});
  @override
  void didPopNext() => setState(() {});
  @override
  void dispose() {
    motionRouteObserver.unsubscribe(this);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MotionGate(
    active: _foreground && (_route?.isCurrent ?? true),
    child: widget.child,
  );
}

class MotionGate extends StatelessWidget {
  const MotionGate({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  static bool activeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionActive>()?.active ??
      true;

  @override
  Widget build(BuildContext context) {
    final enabled = active && activeOf(context);
    return _MotionActive(
      active: enabled,
      child: TickerMode(enabled: enabled, child: child),
    );
  }
}

class _MotionActive extends InheritedWidget {
  const _MotionActive({required this.active, required super.child});
  final bool active;
  @override
  bool updateShouldNotify(_MotionActive oldWidget) =>
      active != oldWidget.active;
}
