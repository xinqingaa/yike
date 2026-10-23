import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../overlay/popup_activity.dart';

final motionRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Combines route, application and selected-panel visibility for local motion.
class MotionVisibility extends ConsumerStatefulWidget {
  const MotionVisibility({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<MotionVisibility> createState() => _MotionVisibilityState();
}

class _MotionVisibilityState extends ConsumerState<MotionVisibility>
    with RouteAware {
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
  Widget build(BuildContext context) {
    final depth = ref.watch(popupActivityProvider);
    return MotionGate(
      active: _foreground && (_route?.isCurrent ?? true) && depth == 0,
      activeNow: () =>
          _foreground &&
          (_route?.isCurrent ?? true) &&
          ref.read(popupActivityProvider) == 0,
      child: widget.child,
    );
  }
}

class MotionGate extends StatelessWidget {
  const MotionGate({
    super.key,
    required this.active,
    required this.child,
    this.activeNow,
  });
  final bool active;
  final ValueGetter<bool>? activeNow;
  final Widget child;

  static bool activeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MotionActive>()?.active ??
      true;

  /// Evaluates source visibility at event time, including before the next build.
  static bool activeNowOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_MotionActive>()?.current() ?? true;

  @override
  Widget build(BuildContext context) {
    final enabled = active && activeOf(context);
    return _MotionActive(
      active: enabled,
      current: () => (activeNow?.call() ?? active) && activeNowOf(context),
      child: TickerMode(enabled: enabled, child: child),
    );
  }
}

class _MotionActive extends InheritedWidget {
  const _MotionActive({
    required this.active,
    required this.current,
    required super.child,
  });
  final bool active;
  final ValueGetter<bool> current;
  @override
  bool updateShouldNotify(_MotionActive oldWidget) =>
      active != oldWidget.active;
}
