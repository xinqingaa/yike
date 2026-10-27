import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/overlay/app_pop.dart';
import '../common/overlay/popup_activity.dart';
import '../common/route_activity.dart';
import '../features/local_data/local_data.dart';
import '../router/routes.dart';
import 'navigation.dart';

/// Android root back confirmation; child routes and popups handle back first.
class RootBackBoundary extends ConsumerStatefulWidget {
  const RootBackBoundary({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<RootBackBoundary> createState() => _RootBackBoundaryState();
}

class _RootBackBoundaryState extends ConsumerState<RootBackBoundary> {
  static const _window = Duration(seconds: 2);
  Timer? _timeout;
  bool _armed = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    appRouteActivity.addListener(_reset);
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _reset());
  }

  void _reset() {
    _timeout?.cancel();
    _timeout = null;
    if (_armed && mounted) setState(() => _armed = false);
  }

  void _back(bool didPop, Object? result) {
    if (didPop ||
        Theme.of(context).platform != TargetPlatform.android ||
        ModalRoute.of(context)?.isCurrent != true ||
        appRouteActivity.current != AppRoutes.home ||
        AppPop.handlesSystemBack ||
        ref.read(popupActivityProvider) > 0) {
      return;
    }
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      _reset();
      return;
    }
    ref.read(localDataProvider.notifier).checkpoint();
    setState(() => _armed = true);
    _timeout?.cancel();
    _timeout = Timer(_window, _reset);
    AppPop.toast('再按一次返回键退出应用', duration: _window, replacementKey: 'root-exit');
  }

  @override
  void dispose() {
    _timeout?.cancel();
    appRouteActivity.removeListener(_reset);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rootTabProvider, (_, _) => _reset());
    ref.listen(popupActivityProvider, (_, _) => _reset());
    return PopScope<Object?>(
      canPop: Theme.of(context).platform != TargetPlatform.android || _armed,
      onPopInvokedWithResult: _back,
      child: widget.child,
    );
  }
}
