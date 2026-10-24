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
    elapsed = elapsed.clamp(0, session.limitMs.toDouble());
    final remaining = (session.targetMs - elapsed).clamp(0, double.infinity);
    final seconds = session.mode == TimerMode.stopwatch
        ? elapsed ~/ 1000
        : (remaining / 1000).ceil();
    final progress =
        (session.mode == TimerMode.stopwatch ? elapsed : remaining) /
        (session.scaleSeconds * 1000);
    return FocusProjection(seconds, progress.clamp(0, 1), elapsed / 1000);
  }
}
