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
