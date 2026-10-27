import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/overlay/app_pop.dart';
import '../common/overlay/popup_activity.dart';
import '../common/route_activity.dart';
import '../common/system_surfaces/surface_models.dart';
import '../features/focus/focus.dart';
import '../features/local_data/local_data.dart';
import '../router/router.dart';
import 'navigation.dart';

/// Viewing is deferred through modal drafts; command execution is independent.
class ExternalTargets extends Notifier<SurfaceIntent?> {
  bool _scheduled = false, _disposed = false;
  @override
  SurfaceIntent? build() {
    ref.listen(popupActivityProvider, (_, _) => navigate());
    ref.listen(localDataProvider, (_, _) {
      if (state != null) navigate();
    });
    final lifecycle = AppLifecycleListener(onResume: navigate);
    appRouteActivity.addListener(navigate);
    ref.onDispose(() {
      _disposed = true;
      lifecycle.dispose();
      appRouteActivity.removeListener(navigate);
    });
    return null;
  }

  void enqueue(SurfaceIntent target) {
    state = target;
    navigate();
  }

  void clear() => state = null;
  void navigate() {
    if (_scheduled || _disposed || state == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed ||
          state == null ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed) ||
          ref.read(popupActivityProvider) > 0 ||
          ref.read(localDataProvider).readError != null ||
          appRouteActivity.current == null) {
        return;
      }
      final target = state!;
      state = null;
      AppDataCard.closeAll();
      appNavigatorKey.currentState?.popUntil(
        (r) => r.settings.name == AppRoutes.home,
      );
      if (target.target == 'focus') {
        if (target.mode != null) {
          ref
              .read(focusActionsProvider)
              .switchMode(TimerMode.values.byName(target.mode!));
        }
        ref.read(rootTabProvider.notifier).set(0);
      } else {
        ref.read(rootTabProvider.notifier).set(1);
        if (target.habit != null) {
          final exists = ref
              .read(localDataProvider)
              .data
              .habits
              .any((h) => h.id == target.habit && !h.archived);
          if (exists) {
            ref.read(habitReminderTargetsProvider.notifier).set({
              ...ref.read(habitReminderTargetsProvider),
              target.habit!,
            });
          } else {
            AppPop.toast('该习惯已删除或归档');
          }
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

final externalTargetsProvider =
    NotifierProvider<ExternalTargets, SurfaceIntent?>(
      ExternalTargets.new,
      dependencies: [localDataProvider, focusActionsProvider],
    );
