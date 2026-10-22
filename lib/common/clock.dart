import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Injectable wall clock. Active sessions reconcile elapsed time on every pulse.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class ClockPulse extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.watch(clockProvider);
    final timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => refresh(),
    );
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(timer.cancel);
    ref.onDispose(lifecycle.dispose);
    return now();
  }

  void refresh() => state = ref.read(clockProvider)();
}

final clockPulseProvider = NotifierProvider<ClockPulse, DateTime>(
  ClockPulse.new,
);
