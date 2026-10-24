import '../../../common/feedback/feedback_cue.dart';
import '../models/focus_view.dart';

/// Returns only the most recent crossed boundary, never an accumulated queue.
/// The caller resets its baseline on lifecycle, session, stage and pause changes.
FeedbackCue? focusBeat({
  required TimerMode mode,
  required TimerStage stage,
  required double previousElapsed,
  required double elapsed,
  required int remainingSeconds,
  required int beatMinutes,
  required bool secondTick,
}) {
  if (elapsed <= previousElapsed || stage != TimerStage.focus) return null;
  if (mode != TimerMode.stopwatch && remainingSeconds <= 0) return null;
  final latestSecond = elapsed.floor();
  // Consider only the latest crossed boundary, never replay an old interval
  // after a multi-second gap. At the same boundary the interval wins.
  if (beatMinutes > 0) {
    final interval = beatMinutes * 60;
    final boundary = elapsed ~/ interval;
    final atLatestSecond = boundary * interval == latestSecond;
    final everySecond =
        secondTick || (mode == TimerMode.countdown && remainingSeconds <= 10);
    if (boundary > 0 &&
        boundary > previousElapsed ~/ interval &&
        (!everySecond || atLatestSecond)) {
      return FeedbackCue.interval;
    }
  }
  if (latestSecond <= previousElapsed.floor()) return null;
  if (mode == TimerMode.countdown && remainingSeconds <= 10) {
    return FeedbackCue.lastSecondsTick;
  }
  return secondTick ? FeedbackCue.tick : null;
}
