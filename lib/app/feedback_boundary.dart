import '../common/route_activity.dart';
import '../common/overlay/popup_activity.dart';
import '../router/routes.dart';
import 'navigation.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/clock.dart';
import '../common/feedback/feedback_service.dart';
import '../features/focus/focus.dart';
import '../features/local_data/local_data.dart';

/// Application composition, not page visibility, owns sound and haptic lifetime.
class FeedbackBoundary extends ConsumerStatefulWidget {
  const FeedbackBoundary({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<FeedbackBoundary> createState() => _FeedbackBoundaryState();
}

class _FeedbackBoundaryState extends ConsumerState<FeedbackBoundary> {
  late final AppLifecycleListener _lifecycle;
  late final FeedbackService _service;
  TimerMode? _allowed;
  late final TimerFeedbackVisibility _visibility;
  bool _allows(TimerMode mode) {
    final depth = ref.read(popupActivityProvider);
    final panels = ref.read(popupActivityProvider.notifier).timerPanelCount;
    return appRouteActivity.current == AppRoutes.home &&
        ref.read(rootTabProvider) == 0 &&
        ref.read(focusDataProvider).mode == mode &&
        (depth == 0 || (mode == TimerMode.stopwatch && depth == panels));
  }

  void _visibilityChanged() {
    final next = TimerMode.values.where(_allows).firstOrNull;
    if (_allowed == next) return;
    if (_allowed != null) _service.stopScope(_allowed!.name);
    _allowed = next;
    final feedback = ref.read(focusFeedbackProvider);
    feedback.reset();
    feedback.sample(ref.read(clockProvider)());
  }

  @override
  void initState() {
    super.initState();
    final service = _service = ref.read(feedbackServiceProvider);
    void updatePreferences(TimingPreferences preferences) => service.configure(
      sound: preferences.sound,
      haptics: preferences.haptics,
      scopes: {
        for (final mode in TimerMode.values)
          mode.name: preferences.feedbackFor(mode),
        'habits': preferences.habitFeedback,
      },
    );
    ref.listenManual(
      localDataProvider,
      (_, next) => updatePreferences(next.data.focus.preferences),
      fireImmediately: true,
    );
    _visibility = ref.read(timerFeedbackVisibilityProvider);
    _visibility.allows = _allows;
    ref.listenManual(rootTabProvider, (_, _) => _visibilityChanged());
    ref.listenManual(popupActivityProvider, (_, _) => _visibilityChanged());
    ref.listenManual(
      focusDataProvider.select((d) => d.mode),
      (_, _) => _visibilityChanged(),
    );
    appRouteActivity.addListener(_visibilityChanged);
    _visibilityChanged();
    final feedback = ref.read(focusFeedbackProvider);
    final state = WidgetsBinding.instance.lifecycleState;
    service.setForeground(state == null || state == AppLifecycleState.resumed);
    feedback.sample(ref.read(clockProvider)());
    unawaited(service.prepare());
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        service.setForeground(false);
        feedback.reset();
        if (state == AppLifecycleState.resumed) {
          // Reconcile while muted, so an end crossed in the background is not replayed.
          ref
              .read(localDataProvider.notifier)
              .advance(ref.read(clockProvider)());
          service.setForeground(true);
          feedback.sample(ref.read(clockProvider)());
        }
      },
    );
  }

  @override
  void dispose() {
    appRouteActivity.removeListener(_visibilityChanged);
    _visibility.allows = (_) => false;
    _lifecycle.dispose();
    _service.setForeground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(focusFeedbackProvider);
    return widget.child;
  }
}
