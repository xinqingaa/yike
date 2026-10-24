import 'dart:math' as math;
import '../../../common/time.dart';
import '../models/focus_data.dart';
import '../models/focus_view.dart';

/// Pure transitions. Identity, accounting and settlement never depend on widgets.
abstract final class FocusEngine {
  static FocusData recover(FocusData data) {
    final s = data.session;
    if (s == null || s.status != TimerStatus.running) return data;
    return data.copyWith(
      session: s.copyWith(
        status: TimerStatus.paused,
        clearAnchor: true,
        recovered: true,
      ),
    );
  }

  static FocusData advance(FocusData data, DateTime now) {
    final s = data.session;
    if (s == null || s.status != TimerStatus.running || s.anchor == null) {
      return data;
    }
    var delta = math.max(0, now.difference(s.anchor!).inMilliseconds);
    delta = math.min(delta, s.limitMs - s.elapsedMs);
    if (delta == 0) return data;
    final days = {...s.days};
    if (!s.resting) {
      var cursor = s.anchor!, remaining = delta;
      while (remaining > 0) {
        final midnight = cursor.isUtc
            ? DateTime.utc(cursor.year, cursor.month, cursor.day + 1)
            : DateTime(cursor.year, cursor.month, cursor.day + 1);
        final part = math.min(
          remaining,
          midnight.difference(cursor).inMilliseconds,
        );
        if (part <= 0) break;
        final date = dayId(cursor);
        days[date] = (days[date] ?? 0) + part;
        cursor = cursor.add(Duration(milliseconds: part));
        remaining -= part;
      }
    }
    final done = s.elapsedMs + delta >= s.limitMs;
    final next = s.copyWith(
      elapsedMs: s.elapsedMs + delta,
      days: Map.unmodifiable(days),
      anchor: now,
      status: done ? TimerStatus.finished : TimerStatus.running,
      clearAnchor: done,
      promptShort:
          done &&
          !s.resting &&
          s.mode != TimerMode.countdown &&
          s.limitMs < data.preferences.threshold * 1000,
    );
    var result = data.copyWith(
      session: next,
      cycles:
          data.cycles +
          (done && !s.resting && s.mode == TimerMode.pomodoro ? 1 : 0),
    );
    if (done && !s.resting && !next.promptShort) result = record(result);
    return result;
  }

  static FocusData start(FocusData data, DateTime now, String id) {
    if (data.session != null) return data;
    final target = data.mode == TimerMode.stopwatch
        ? 0
        : (data.mode == TimerMode.countdown
                  ? data.countdown
                  : data.pomodoroOnce ?? data.preferences.focusSeconds) *
              1000;
    if (data.mode != TimerMode.stopwatch &&
        (target < 1000 || target > maxFocusSeconds * 1000)) {
      return data;
    }
    return data.copyWith(
      clearPomodoroOnce: data.mode == TimerMode.pomodoro,
      session: FocusSession(
        id: id,
        mode: data.mode,
        stage: TimerStage.focus,
        status: TimerStatus.running,
        startedAt: now,
        targetMs: target,
        scaleSeconds: data.mode == TimerMode.countdown
            ? data.countdownScale
            : fullDialSeconds,
        round: data.cycles + 1,
        longRest:
            data.mode == TimerMode.pomodoro &&
            data.cycles + 1 >= data.preferences.interval,
        anchor: now,
      ),
    );
  }

  static FocusData again(FocusData data, DateTime now, String id) {
    final previous = data.session;
    if (previous == null ||
        previous.mode != TimerMode.countdown ||
        previous.status != TimerStatus.finished) {
      return data;
    }
    return data.copyWith(
      session: FocusSession(
        id: id,
        mode: TimerMode.countdown,
        stage: TimerStage.focus,
        status: TimerStatus.running,
        startedAt: now,
        targetMs: previous.targetMs,
        scaleSeconds: previous.scaleSeconds,
        round: previous.round,
        longRest: false,
        anchor: now,
      ),
    );
  }

  static FocusData pause(FocusData data, DateTime now) {
    final result = advance(data, now), s = result.session;
    if (s == null || s.status != TimerStatus.running) return result;
    return result.copyWith(
      session: s.copyWith(
        status: TimerStatus.paused,
        clearAnchor: true,
        recovered: false,
      ),
    );
  }

  static FocusData resume(FocusData data, DateTime now) {
    final s = data.session;
    if (s == null || s.status != TimerStatus.paused) return data;
    return data.copyWith(
      session: s.copyWith(
        status: TimerStatus.running,
        anchor: now,
        recovered: false,
      ),
    );
  }

  static FocusData lap(FocusData data, DateTime now) {
    final result = advance(data, now), s = result.session;
    if (s == null ||
        s.mode != TimerMode.stopwatch ||
        s.status != TimerStatus.running ||
        s.elapsedMs ~/ 1000 <= (s.laps.lastOrNull ?? 0) ~/ 1000) {
      return result;
    }
    return result.copyWith(
      session: s.copyWith(laps: List.unmodifiable([...s.laps, s.elapsedMs])),
    );
  }

  static bool needsConfirmation(FocusData data) {
    final s = data.session;
    return s != null &&
        !s.resting &&
        s.elapsedMs > 0 &&
        s.elapsedMs < data.preferences.threshold * 1000 &&
        !data.records.any((r) => r.sessionId == s.id) &&
        !(s.mode == TimerMode.countdown && s.status == TimerStatus.finished);
  }

  static FocusData record(FocusData data) {
    final s = data.session;
    if (s == null ||
        s.resting ||
        s.elapsedMs == 0 ||
        data.records.any((r) => r.sessionId == s.id)) {
      return data;
    }
    return data.copyWith(
      records: List.unmodifiable([
        ...data.records,
        FocusRecord(
          sessionId: s.id,
          mode: s.mode,
          startedAt: s.startedAt,
          elapsedMs: s.elapsedMs,
          days: Map.unmodifiable(s.days),
        ),
      ]),
      session: s.copyWith(promptShort: false),
    );
  }

  static FocusData finish(
    FocusData data,
    DateTime now, {
    bool acceptShort = false,
  }) {
    final result = pause(data, now);
    if (needsConfirmation(result) && !acceptShort) return result;
    return leave(record(result));
  }

  static FocusData leave(FocusData data) {
    final s = data.session;
    return data.copyWith(
      clearSession: true,
      cycles:
          s != null &&
              s.mode == TimerMode.pomodoro &&
              s.longRest &&
              (s.resting || s.status == TimerStatus.finished)
          ? 0
          : data.cycles,
      countdown: s?.mode == TimerMode.countdown
          ? s!.targetMs ~/ 1000
          : data.countdown,
    );
  }

  static FocusData beginBreak(
    FocusData data,
    DateTime now,
    String id, {
    bool acceptShort = false,
  }) {
    final s = data.session;
    if (s == null ||
        s.mode != TimerMode.pomodoro ||
        s.resting ||
        s.status != TimerStatus.finished ||
        needsConfirmation(data) && !acceptShort) {
      return data;
    }
    final result = record(data);
    return result.copyWith(
      session: FocusSession(
        id: id,
        mode: TimerMode.pomodoro,
        stage: s.longRest ? TimerStage.longBreak : TimerStage.shortBreak,
        status: TimerStatus.running,
        startedAt: now,
        targetMs:
            (s.longRest
                ? data.preferences.longSeconds
                : data.preferences.shortSeconds) *
            1000,
        round: s.round,
        longRest: s.longRest,
        anchor: now,
      ),
    );
  }
}
