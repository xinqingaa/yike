import '../../../common/time.dart';
import 'focus_view.dart';

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

Map<String, dynamic> preferencesJson(TimingPreferences p) => {
  'focus': p.focusMinutes,
  'short': p.shortMinutes,
  'long': p.longMinutes,
  'interval': p.interval,
  'threshold': p.threshold,
  'sound': p.sound,
  'presets': p.presets,
};
TimingPreferences preferencesFromJson(Map<String, dynamic> j) {
  final slots = (j['presets'] as List)
      .map((v) => v == null ? null : boundedInt(v, 1, 86399))
      .toList();
  if (slots.length != 4 ||
      slots.whereType<int>().toSet().length != slots.whereType<int>().length) {
    throw const FormatException('Invalid presets');
  }
  return TimingPreferences(
    focusMinutes: boundedInt(j['focus'], 1, 180),
    shortMinutes: boundedInt(j['short'], 1, 60),
    longMinutes: boundedInt(j['long'], 1, 60),
    interval: boundedInt(j['interval'], 2, 8),
    threshold: boundedInt(j['threshold'], 1, 86399),
    sound: j['sound'] as bool,
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
    this.elapsedMs = 0,
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
  final int targetMs, elapsedMs, round;
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
    round: round,
    longRest: longRest,
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
    'elapsedMs': elapsedMs,
    'round': round,
    'longRest': longRest,
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
    if ((mode == TimerMode.stopwatch &&
            (target != 0 ||
                status == TimerStatus.finished ||
                laps.isNotEmpty && elapsed == 0)) ||
        (mode != TimerMode.stopwatch &&
            (target % 1000 != 0 ||
                target < 1000 ||
                (status == TimerStatus.finished
                    ? elapsed != target
                    : elapsed >= target))) ||
        (mode != TimerMode.stopwatch && laps.isNotEmpty) ||
        (mode == TimerMode.pomodoro &&
            (target % 60000 != 0 ||
                target > (stage == TimerStage.focus ? 180 : 60) * 60000))) {
      throw const FormatException('Invalid phase state');
    }
    return FocusSession(
      id: id,
      mode: mode,
      stage: stage,
      status: status,
      startedAt: storedTime(j['startedAt']),
      targetMs: target,
      elapsedMs: elapsed,
      round: boundedInt(j['round'], 1, 8),
      longRest: j['longRest'] as bool,
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
    this.session,
    this.records = const [],
    this.cycles = 0,
    this.mode = TimerMode.pomodoro,
    this.countdown = 300,
  });
  final TimingPreferences preferences;
  final FocusSession? session;
  final List<FocusRecord> records;
  final int cycles, countdown;
  final TimerMode mode;
  FocusData copyWith({
    TimingPreferences? preferences,
    FocusSession? session,
    bool clearSession = false,
    List<FocusRecord>? records,
    int? cycles,
    TimerMode? mode,
    int? countdown,
  }) => FocusData(
    preferences: preferences ?? this.preferences,
    session: clearSession ? null : session ?? this.session,
    records: records ?? this.records,
    cycles: cycles ?? this.cycles,
    mode: mode ?? this.mode,
    countdown: countdown ?? this.countdown,
  );
  FocusViewData get view {
    final s = session;
    final target = s == null
        ? (mode == TimerMode.stopwatch
              ? 0
              : mode == TimerMode.countdown
              ? countdown
              : preferences.focusMinutes * 60)
        : s.targetMs ~/ 1000;
    return FocusViewData(
      mode: s?.mode ?? mode,
      status: s?.status ?? TimerStatus.ready,
      stage: s?.stage ?? TimerStage.focus,
      target: target,
      seconds: s == null
          ? target
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
    'session': session?.toJson(),
    'records': records.map((r) => r.toJson()).toList(),
    'cycles': cycles,
  };
  factory FocusData.fromJson(Map<String, dynamic> j) {
    final prefs = preferencesFromJson(j['preferences'] as Map<String, dynamic>);
    final session = j['session'] == null
        ? null
        : FocusSession.fromJson(j['session'] as Map<String, dynamic>);
    final records = (j['records'] as List)
        .map((r) => FocusRecord.fromJson(r as Map<String, dynamic>))
        .toList();
    if (records.map((r) => r.sessionId).toSet().length != records.length) {
      throw const FormatException('Duplicate focus record');
    }
    return FocusData(
      preferences: prefs,
      session: session,
      records: List.unmodifiable(records),
      cycles: boundedInt(j['cycles'], 0, 8),
      mode: session?.mode ?? TimerMode.pomodoro,
      countdown: session?.mode == TimerMode.countdown
          ? session!.targetMs ~/ 1000
          : prefs.presets.contains(300)
          ? 300
          : prefs.presets.whereType<int>().firstOrNull ?? 300,
    );
  }
}
