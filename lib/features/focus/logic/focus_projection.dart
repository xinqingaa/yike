import '../models/focus_data.dart';
import '../models/focus_view.dart';

/// A read-only frame projection. Settlement remains in FocusEngine.
class FocusProjection {
  const FocusProjection(this.seconds, this.progress, this.elapsedSeconds);
  final int seconds;
  final double progress, elapsedSeconds;

  factory FocusProjection.at(
    FocusSession? session,
    FocusViewData view,
    DateTime now,
  ) {
    if (session == null) return FocusProjection(view.seconds, view.progress, 0);
    var elapsed = session.elapsedMs.toDouble();
    if (session.status == TimerStatus.running && session.anchor != null) {
      elapsed +=
          now.difference(session.anchor!).inMicroseconds.clamp(0, 1 << 53) /
          1000;
    }
    if (session.mode != TimerMode.stopwatch) {
      elapsed = elapsed.clamp(0, session.targetMs.toDouble());
    }
    final remaining = (session.targetMs - elapsed).clamp(0, double.infinity);
    final seconds = session.mode == TimerMode.stopwatch
        ? elapsed ~/ 1000
        : (remaining / 1000).ceil();
    final progress = session.mode == TimerMode.countdown
        ? remaining / session.targetMs
        : session.mode == TimerMode.stopwatch
        ? (elapsed > 0 && elapsed % 3600000 == 0
              ? 1.0
              : (elapsed % 3600000) / 3600000)
        : remaining / 3600000;
    return FocusProjection(seconds, progress.clamp(0, 1), elapsed / 1000);
  }
}
