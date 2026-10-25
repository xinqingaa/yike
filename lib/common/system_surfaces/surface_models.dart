import 'dart:convert';

/// Wire types shared with WidgetKit/RemoteViews. They never own business facts.
class SurfaceTimer {
  const SurfaceTimer({
    required this.mode,
    required this.session,
    required this.stage,
    required this.status,
    required this.elapsedMs,
    required this.limitMs,
    required this.scaleSeconds,
    required this.round,
    required this.laps,
    this.anchorMs,
    this.token,
  });
  final String mode, session, stage, status;
  final int elapsedMs, limitMs, scaleSeconds, round, laps;

  /// Running timers use a normalized zero-elapsed anchor, stable across pulses.
  final int? anchorMs;
  final String? token;
  String get stateToken => token ?? '$status/${anchorMs ?? elapsedMs}';
  bool get active => status == 'running' || status == 'paused';
  int elapsedAt(DateTime now) =>
      (status == 'running' && anchorMs != null
              ? now.millisecondsSinceEpoch - anchorMs!
              : elapsedMs)
          .clamp(0, limitMs);
  int remainingAt(DateTime now) => limitMs - elapsedAt(now);
  Map<String, Object?> toJson() => {
    'mode': mode,
    'session': session,
    'stage': stage,
    'status': status,
    'elapsedMs': elapsedMs,
    'anchorMs': anchorMs,
    'limitMs': limitMs,
    'scaleSeconds': scaleSeconds,
    'round': round,
    'laps': laps,
    'token': stateToken,
  };
}

SurfaceTimer? priorityTimer(List<SurfaceTimer> timers, DateTime now) {
  const order = ['pomodoro', 'stopwatch', 'countdown'];
  final running =
      timers
          .where((t) => t.status == 'running' && t.remainingAt(now) > 0)
          .toList()
        ..sort((a, b) {
          final time = a.remainingAt(now).compareTo(b.remainingAt(now));
          return time != 0
              ? time
              : order.indexOf(a.mode).compareTo(order.indexOf(b.mode));
        });
  if (running.isNotEmpty) return running.first;
  for (final mode in order) {
    for (final timer in timers) {
      if (timer.mode == mode && timer.status == 'paused') return timer;
    }
  }
  return null;
}

class SurfaceSnapshot {
  const SurfaceSnapshot({
    required this.epoch,
    required this.revision,
    required this.generatedMs,
    required this.date,
    required this.timezone,
    required this.readable,
    required this.unsaved,
    required this.liveEnabled,
    required this.theme,
    required this.appearance,
    required this.timers,
    required this.todaySeconds,
    required this.habitTotal,
    required this.habitDone,
    required this.habits,
    this.palette = const {},
  });
  final String epoch, date, timezone, theme, appearance;
  final int revision, generatedMs, todaySeconds, habitTotal, habitDone;
  final bool readable, unsaved, liveEnabled;
  final List<SurfaceTimer> timers;
  final List<Map<String, Object>> habits;
  final Map<String, String> palette;
  Map<String, Object?> toJson() => {
    'version': 1,
    'epoch': epoch,
    'revision': revision,
    'generatedMs': generatedMs,
    'date': date,
    'timezone': timezone,
    'readable': readable,
    'unsaved': unsaved,
    'liveEnabled': liveEnabled,
    'theme': theme,
    'appearance': appearance,
    'timers': timers.map((t) => t.toJson()).toList(),
    'todaySeconds': todaySeconds,
    'habitTotal': habitTotal,
    'habitDone': habitDone,
    'habits': habits,
    'palette': palette,
  };
  String encode() => jsonEncode(toJson());
}

/// Commands are explicit, never toggles. A display revision makes re-delivery
/// idempotent even if a user later returns to the command's expected state.
class SurfaceIntent {
  const SurfaceIntent({
    required this.target,
    this.action = 'view',
    this.mode,
    this.session,
    this.stage,
    this.expected,
    this.epoch,
    this.revision,
    this.token,
    this.habit,
  });
  final String target, action;
  final String? mode, session, stage, expected, epoch, token, habit;
  final int? revision;
  bool get isCommand => action != 'view';
  String get commandKey => '$epoch/$revision/$mode/$session/$stage/$action';
  static SurfaceIntent? decode(String? raw) {
    try {
      final url = Uri.parse(raw!);
      if (url.scheme != 'yike' ||
          url.host != 'surface' ||
          url.path.isNotEmpty) {
        return null;
      }
      final q = url.queryParameters;
      if (q['v'] != '1') return null;
      final target = q['target'];
      final action = q['action'] ?? 'view';
      if (!const ['focus', 'habits'].contains(target) ||
          !const ['view', 'pause', 'resume'].contains(action)) {
        return null;
      }
      final mode = q['mode'];
      if (mode != null &&
          !const ['pomodoro', 'stopwatch', 'countdown'].contains(mode)) {
        return null;
      }
      final revision = int.tryParse(q['revision'] ?? '');
      if (action != 'view' &&
          (target != 'focus' ||
              mode == null ||
              (q['session']?.isEmpty ?? true) ||
              !const [
                'focus',
                'shortBreak',
                'longBreak',
              ].contains(q['stage']) ||
              (q['epoch']?.isEmpty ?? true) ||
              revision == null ||
              revision < 0 ||
              (q['token']?.isEmpty ?? true) ||
              q['expected'] != (action == 'pause' ? 'running' : 'paused'))) {
        return null;
      }
      return SurfaceIntent(
        target: target!,
        action: action,
        mode: mode,
        session: q['session'],
        stage: q['stage'],
        expected: q['expected'],
        epoch: q['epoch'],
        revision: revision,
        token: q['token'],
        habit: q['habit'],
      );
    } catch (_) {
      return null;
    }
  }
}

class SurfaceAccess {
  const SurfaceAccess({
    this.widgets = false,
    this.activities = false,
    this.allowed = false,
    this.shared = false,
  });
  final bool widgets, activities, allowed, shared;
}

abstract interface class SystemSurfaceAdapter {
  Future<void> initialize(void Function(String) receive);
  Future<SurfaceAccess> access();
  Future<void> publish(SurfaceSnapshot snapshot);
  Future<void> clear();
  Future<void> openSettings();
  void dispose();
}
