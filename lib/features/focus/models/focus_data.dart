import '../../../common/time.dart';
import 'focus_view.dart';
import '../../../common/feedback/feedback_options.dart';

int boundedInt(dynamic value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('Invalid number');
  }
  return value;
}

DateTime storedTime(dynamic value) => DateTime.parse(value as String);
String validDay(dynamic value) {
  final parsed = DateTime.parse(value as String);
  if (dayId(parsed) != value) throw const FormatException('Invalid date');
  return value;
}

Map<String, dynamic> feedbackOptionsJson(
  FeedbackOptions value, {
  bool timer = true,
}) => {
  'sound': value.sound,
  'haptics': value.haptics,
  if (timer) 'secondTick': value.secondTick,
  if (timer) 'beatMinutes': value.beatMinutes,
};
int validBeat(dynamic value) {
  final beat = boundedInt(value, 0, 15);
  if (!const [0, 1, 5, 10, 15].contains(beat)) {
    throw const FormatException('Invalid beat interval');
  }
  return beat;
}

FeedbackOptions feedbackOptionsFromJson(dynamic value, {bool timer = true}) {
  final j = value as Map<String, dynamic>;
  return FeedbackOptions(
    sound: j['sound'] as bool,
    haptics: j['haptics'] as bool,
    secondTick: timer ? j['secondTick'] as bool : false,
    beatMinutes: timer ? validBeat(j['beatMinutes']) : 0,
  );
}

Map<String, dynamic> preferencesJson(TimingPreferences p) => {
  'focusSeconds': p.focusSeconds,
  'shortSeconds': p.shortSeconds,
  'longSeconds': p.longSeconds,
  'interval': p.interval,
  'threshold': p.threshold,
  'sound': p.sound,
  'haptics': p.haptics,
  'feedback': {
    for (final mode in TimerMode.values)
      mode.name: feedbackOptionsJson(p.feedbackFor(mode)),
    'habits': feedbackOptionsJson(p.habitFeedback, timer: false),
  },
  'presets': p.presets,
};
TimingPreferences preferencesFromJson(Map<String, dynamic> j) {
  final slots = (j['presets'] as List)
      .map((v) => v == null ? null : boundedInt(v, 1, maxFocusSeconds))
      .toList();
  if (slots.length != 4 ||
      slots.first == null ||
      slots.whereType<int>().toSet().length != slots.whereType<int>().length) {
    throw const FormatException('Invalid presets');
  }
  final groups = j['feedback'] as Map<String, dynamic>;
  return TimingPreferences(
    focusSeconds: boundedInt(j['focusSeconds'], 1, maxFocusSeconds),
    shortSeconds: boundedInt(j['shortSeconds'], 1, 59),
    longSeconds: boundedInt(j['longSeconds'], 1, maxFocusSeconds),
    interval: boundedInt(j['interval'], 2, 8),
    threshold: boundedInt(j['threshold'], 1, 86399),
    sound: j['sound'] as bool,
    haptics: j['haptics'] as bool,
    pomodoroFeedback: feedbackOptionsFromJson(groups['pomodoro']),
    stopwatchFeedback: feedbackOptionsFromJson(groups['stopwatch']),
    countdownFeedback: feedbackOptionsFromJson(groups['countdown']),
    habitFeedback: feedbackOptionsFromJson(groups['habits'], timer: false),
    presets: List.unmodifiable(slots),
  );
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.mode,
    required this.stage,
    required this.status,
    required this.startedAt,
    required this.targetMs,
    required this.round,
    required this.longRest,
    this.shortSeconds = 30,
    this.longSeconds = 900,
    this.interval = 4,
    this.elapsedMs = 0,
    this.scaleSeconds = fullDialSeconds,
    this.days = const {},
    this.laps = const [],
    this.anchor,
    this.recovered = false,
    this.promptShort = false,
  });
  final String id;
  final TimerMode mode;
  final TimerStage stage;
  final TimerStatus status;
  final DateTime startedAt;
  final int targetMs, elapsedMs, round, scaleSeconds;
  int get limitMs =>
      mode == TimerMode.stopwatch ? maxFocusSeconds * 1000 : targetMs;
  final int shortSeconds, longSeconds, interval;
  final bool longRest, recovered, promptShort;
  final Map<String, int> days;
  final List<int> laps;
  final DateTime? anchor;
  bool get resting => stage != TimerStage.focus;
  FocusSession copyWith({
    TimerStatus? status,
    int? elapsedMs,
    Map<String, int>? days,
    List<int>? laps,
    DateTime? anchor,
    bool clearAnchor = false,
    bool? recovered,
    bool? promptShort,
  }) => FocusSession(
    id: id,
    mode: mode,
    stage: stage,
    status: status ?? this.status,
    startedAt: startedAt,
    targetMs: targetMs,
    scaleSeconds: scaleSeconds,
    round: round,
    longRest: longRest,
    shortSeconds: shortSeconds,
    longSeconds: longSeconds,
    interval: interval,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    days: days ?? this.days,
    laps: laps ?? this.laps,
    anchor: clearAnchor ? null : anchor ?? this.anchor,
    recovered: recovered ?? this.recovered,
    promptShort: promptShort ?? this.promptShort,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode.name,
    'stage': stage.name,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'targetMs': targetMs,
    'scaleSeconds': scaleSeconds,
    'elapsedMs': elapsedMs,
    'round': round,
    'longRest': longRest,
    'shortSeconds': shortSeconds,
    'longSeconds': longSeconds,
    'interval': interval,
    'days': days,
    'laps': laps,
    'promptShort': promptShort,
  };
  factory FocusSession.fromJson(Map<String, dynamic> j) {
    final mode = TimerMode.values.byName(j['mode'] as String);
    final stage = TimerStage.values.byName(j['stage'] as String);
    final status = TimerStatus.values.byName(j['status'] as String);
    final elapsed = boundedInt(j['elapsedMs'], 0, 1 << 53),
        target = boundedInt(j['targetMs'], 0, 86399000);
    final days = (j['days'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(validDay(k), boundedInt(v, 0, 1 << 53)),
    );
    final laps = (j['laps'] as List)
        .map((v) => boundedInt(v, 1, elapsed))
        .toList();
    final id = j['id'] as String;
    if (id.isEmpty ||
        status == TimerStatus.ready ||
        (mode != TimerMode.stopwatch && (target < 1 || elapsed > target)) ||
        (mode != TimerMode.pomodoro && stage != TimerStage.focus) ||
        (!(stage != TimerStage.focus) &&
            days.values.fold<int>(0, (a, b) => a + b) != elapsed) ||
        (stage != TimerStage.focus && days.isNotEmpty) ||
        laps.indexed.any((e) => e.$1 > 0 && e.$2 <= laps[e.$1 - 1])) {
      throw const FormatException('Invalid session');
    }
    final scale = boundedInt(j['scaleSeconds'], 1, fullDialSeconds);
    final limit = mode == TimerMode.stopwatch ? maxFocusSeconds * 1000 : target;
    if (elapsed > limit ||
        (mode == TimerMode.stopwatch &&
            (target != 0 || laps.isNotEmpty && elapsed == 0)) ||
        (mode != TimerMode.stopwatch &&
            (target % 1000 != 0 ||
                target < 1000 ||
                target > maxFocusSeconds * 1000)) ||
        (status == TimerStatus.finished
            ? elapsed != limit
            : elapsed >= limit) ||
        (mode != TimerMode.stopwatch && laps.isNotEmpty) ||
        (stage == TimerStage.shortBreak && target > 59000) ||
        (mode == TimerMode.countdown
            ? scale * 1000 < target
            : scale != fullDialSeconds)) {
      throw const FormatException('Invalid phase state');
    }
    return FocusSession(
      id: id,
      mode: mode,
      stage: stage,
      status: status,
      startedAt: storedTime(j['startedAt']),
      targetMs: target,
      scaleSeconds: scale,
      elapsedMs: elapsed,
      round: boundedInt(j['round'], 1, 8),
      longRest: j['longRest'] as bool,
      shortSeconds: boundedInt(j['shortSeconds'], 1, 59),
      longSeconds: boundedInt(j['longSeconds'], 1, maxFocusSeconds),
      interval: boundedInt(j['interval'], 2, 8),
      days: Map.unmodifiable(days),
      laps: List.unmodifiable(laps),
      promptShort: j['promptShort'] as bool,
    );
  }
}

class FocusRecord {
  const FocusRecord({
    required this.sessionId,
    required this.mode,
    required this.startedAt,
    required this.elapsedMs,
    required this.days,
  });
  final String sessionId;
  final TimerMode mode;
  final DateTime startedAt;
  final int elapsedMs;
  final Map<String, int> days;
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'mode': mode.name,
    'startedAt': startedAt.toIso8601String(),
    'elapsedMs': elapsedMs,
    'days': days,
  };
  factory FocusRecord.fromJson(Map<String, dynamic> j) {
    final days = (j['days'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(validDay(k), boundedInt(v, 1, 1 << 53)),
    );
    final elapsed = boundedInt(j['elapsedMs'], 1, 1 << 53),
        id = j['sessionId'] as String;
    if (id.isEmpty || days.values.fold<int>(0, (a, b) => a + b) != elapsed) {
      throw const FormatException('Invalid record');
    }
    return FocusRecord(
      sessionId: id,
      mode: TimerMode.values.byName(j['mode'] as String),
      startedAt: storedTime(j['startedAt']),
      elapsedMs: elapsed,
      days: Map.unmodifiable(days),
    );
  }
}

class FocusData {
  const FocusData({
    this.preferences = const TimingPreferences(),
    this.sessions = const {},
    this.records = const [],
    this.cycles = 0,
    this.mode = TimerMode.pomodoro,
    int? countdown,
    this.pomodoroOnce,
    int countdownPreset = 0,
    this.dialAdjusted = false,
    // Public constructor names describe the draft; getters enforce preset bounds.
    // ignore: prefer_initializing_formals
  }) : _countdown = countdown,
       // ignore: prefer_initializing_formals
       _countdownPreset = countdownPreset;
  final TimingPreferences preferences;
  final Map<TimerMode, FocusSession> sessions;
  FocusSession? sessionFor(TimerMode mode) => sessions[mode];
  FocusSession? get session => sessionFor(mode);
  Map<TimerMode, FocusSession> get allSessions => sessions;
  final List<FocusRecord> records;
  final int cycles;
  final int? _countdown;
  final int _countdownPreset;
  final TimerMode mode;
  final int? pomodoroOnce;
  final bool dialAdjusted;
  int get countdownPreset =>
      _countdownPreset >= 0 &&
          _countdownPreset < preferences.presets.length &&
          preferences.presets[_countdownPreset] != null
      ? _countdownPreset
      : 0;
  int get countdownMaximum => preferences.presets[countdownPreset]!;
  int get countdownScale => countdownMaximum;
  int get countdown =>
      (_countdown ?? countdownMaximum).clamp(1, countdownMaximum);
  FocusData copyWith({
    TimingPreferences? preferences,
    FocusSession? session,
    Map<TimerMode, FocusSession>? sessions,
    bool clearSession = false,
    List<FocusRecord>? records,
    int? cycles,
    TimerMode? mode,
    int? countdown,
    int? pomodoroOnce,
    bool clearPomodoroOnce = false,
    int? countdownPreset,
    bool? dialAdjusted,
  }) => FocusData(
    preferences: preferences ?? this.preferences,
    sessions: Map.unmodifiable(
      {
        ...(sessions ?? allSessions),
        if (session != null && !clearSession) session.mode: session,
      }..removeWhere((key, _) => clearSession && key == this.mode),
    ),
    records: records ?? this.records,
    cycles: cycles ?? this.cycles,
    mode: mode ?? this.mode,
    countdown: countdown ?? this.countdown,
    pomodoroOnce: clearPomodoroOnce ? null : pomodoroOnce ?? this.pomodoroOnce,
    countdownPreset: countdownPreset ?? this.countdownPreset,
    dialAdjusted: dialAdjusted ?? this.dialAdjusted,
  );
  FocusViewData get view {
    final s = session;
    final target = s == null
        ? (mode == TimerMode.stopwatch
              ? maxFocusSeconds
              : mode == TimerMode.countdown
              ? countdown
              : pomodoroOnce ?? preferences.focusSeconds)
        : s.targetMs ~/ 1000;
    return FocusViewData(
      mode: s?.mode ?? mode,
      status: s?.status ?? TimerStatus.ready,
      stage: s?.stage ?? TimerStage.focus,
      target: target,
      scaleSeconds:
          s?.scaleSeconds ??
          (mode == TimerMode.countdown ? countdownScale : fullDialSeconds),
      seconds: s == null
          ? mode == TimerMode.stopwatch
                ? 0
                : target
          : s.mode == TimerMode.stopwatch
          ? s.elapsedMs ~/ 1000
          : ((s.targetMs - s.elapsedMs) / 1000).ceil(),
      round: s?.round ?? cycles + 1,
      laps: s?.laps.map((v) => v ~/ 1000).toList() ?? const [],
      recovered: s?.recovered ?? false,
    );
  }

  List<FocusRecordView> get dailyRecords => [
    for (final r in records)
      for (final d in r.days.entries)
        FocusRecordView(
          date: d.key,
          time:
              '${r.startedAt.hour.toString().padLeft(2, '0')}:${r.startedAt.minute.toString().padLeft(2, '0')}',
          seconds: d.value / 1000,
          mode: r.mode,
          sessionId: r.sessionId,
        ),
  ];
  Map<String, dynamic> toJson() => {
    'preferences': preferencesJson(preferences),
    'sessions': allSessions.values.map((s) => s.toJson()).toList(),
    'records': records.map((r) => r.toJson()).toList(),
    'cycles': cycles,
  };
  factory FocusData.fromJson(Map<String, dynamic> j) {
    final prefs = preferencesFromJson(j['preferences'] as Map<String, dynamic>);
    final sessions = (j['sessions'] as List)
        .map((s) => FocusSession.fromJson(s as Map<String, dynamic>))
        .toList();
    if (sessions.map((s) => s.mode).toSet().length != sessions.length ||
        sessions.map((s) => s.id).toSet().length != sessions.length) {
      throw const FormatException('Duplicate session slot or identity');
    }
    final records = (j['records'] as List)
        .map((r) => FocusRecord.fromJson(r as Map<String, dynamic>))
        .toList();
    if (records.map((r) => r.sessionId).toSet().length != records.length) {
      throw const FormatException('Duplicate focus record');
    }
    return FocusData(
      preferences: prefs,
      sessions: Map.unmodifiable({for (final s in sessions) s.mode: s}),
      records: List.unmodifiable(records),
      cycles: boundedInt(j['cycles'], 0, 8),
    );
  }
}
