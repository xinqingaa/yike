import 'package:flutter/foundation.dart';
import '../../../common/feedback/feedback_options.dart';

const maxFocusSeconds = 3599;
const fullDialSeconds = 3600;
const maxPomodoroRounds = 99;

TimerStage? pomodoroBreak(
  int round, {
  required int shortInterval,
  required int longInterval,
  required int totalRounds,
}) {
  if (totalRounds > 0 && round >= totalRounds) return null;
  if (longInterval > 0 && round % longInterval == 0) {
    return TimerStage.longBreak;
  }
  if (shortInterval > 0 && round % shortInterval == 0) {
    return TimerStage.shortBreak;
  }
  return null;
}

int pomodoroCycleLength(int shortInterval, int longInterval, int totalRounds) {
  if (totalRounds > 0) return totalRounds;
  if (shortInterval == 0) return longInterval;
  if (longInterval == 0) return shortInterval;
  var a = shortInterval, b = longInterval;
  while (b != 0) {
    final remainder = a % b;
    a = b;
    b = remainder;
  }
  return shortInterval ~/ a * longInterval;
}

enum TimerMode { pomodoro, stopwatch, countdown }

enum TimerStatus { ready, running, paused, finished }

enum TimerStage { focus, shortBreak, longBreak }

@immutable
class FocusViewData {
  const FocusViewData({
    this.mode = TimerMode.pomodoro,
    this.status = TimerStatus.ready,
    this.stage = TimerStage.focus,
    this.seconds = 1500,
    this.target = 1500,
    this.scaleSeconds = fullDialSeconds,
    this.round = 1,
    this.laps = const [],
    this.recovered = false,
    this.breakStage,
    this.planComplete = false,
    this.roundCount = 4,
  });
  final TimerMode mode;
  final TimerStatus status;
  final TimerStage stage;
  final int seconds, target, round, scaleSeconds;
  final List<int> laps;
  final bool recovered, planComplete;
  final TimerStage? breakStage;
  final int roundCount;
  bool get resting => stage != TimerStage.focus;
  bool get ready => status == TimerStatus.ready;
  bool get paused => status == TimerStatus.paused;
  bool get finished => status == TimerStatus.finished;
  String get caption => finished
      ? resting
            ? '休息结束'
            : mode == TimerMode.countdown
            ? '到点了'
            : mode == TimerMode.stopwatch
            ? '计时完成'
            : '本轮完成'
      : paused
      ? resting
            ? '休息已暂停'
            : '已暂停'
      : ready
      ? mode == TimerMode.stopwatch
            ? '准备开始'
            : '拨动调整'
      : resting
      ? stage == TimerStage.longBreak
            ? '长休息'
            : '短休息'
      : mode == TimerMode.stopwatch
      ? '已计时'
      : '剩余';
  double get progress => (seconds / scaleSeconds).clamp(0, 1);
  @override
  bool operator ==(Object other) =>
      other is FocusViewData &&
      mode == other.mode &&
      status == other.status &&
      stage == other.stage &&
      seconds == other.seconds &&
      target == other.target &&
      scaleSeconds == other.scaleSeconds &&
      round == other.round &&
      recovered == other.recovered &&
      breakStage == other.breakStage &&
      planComplete == other.planComplete &&
      roundCount == other.roundCount &&
      listEquals(laps, other.laps);
  @override
  int get hashCode => Object.hash(
    mode,
    status,
    stage,
    seconds,
    target,
    scaleSeconds,
    round,
    recovered,
    breakStage,
    planComplete,
    roundCount,
    Object.hashAll(laps),
  );
  FocusViewData copyWith({
    TimerMode? mode,
    TimerStatus? status,
    TimerStage? stage,
    int? seconds,
    int? target,
    int? scaleSeconds,
    int? round,
    List<int>? laps,
    bool? recovered,
  }) => FocusViewData(
    mode: mode ?? this.mode,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    seconds: seconds ?? this.seconds,
    target: target ?? this.target,
    scaleSeconds: scaleSeconds ?? this.scaleSeconds,
    round: round ?? this.round,
    laps: laps ?? this.laps,
    recovered: recovered ?? this.recovered,
    breakStage: breakStage,
    planComplete: planComplete,
    roundCount: roundCount,
  );
}

@immutable
class FocusRecordView {
  const FocusRecordView({
    required this.date,
    required this.time,
    required this.seconds,
    required this.mode,
    this.sessionId = '',
  });
  final String date, time, sessionId;
  final num seconds;
  final TimerMode mode;
}

@immutable
class TimingPreferences {
  const TimingPreferences({
    this.focusSeconds = 1500,
    this.shortSeconds = 300,
    this.longSeconds = 900,
    this.interval = 4,
    this.shortInterval = 1,
    this.totalRounds = 0,
    this.threshold = 10,
    this.sound = true,
    this.haptics = true,
    this.pomodoroFeedback = const FeedbackOptions(),
    this.stopwatchFeedback = const FeedbackOptions(),
    this.countdownFeedback = const FeedbackOptions(
      secondTick: true,
      beatMinutes: 0,
    ),
    this.habitFeedback = const FeedbackOptions(beatMinutes: 0),
    this.presets = const [180, 300, 600, 1200],
  });
  final int focusSeconds, shortSeconds, longSeconds, interval, threshold;
  final int shortInterval, totalRounds;
  int get cycleLength =>
      pomodoroCycleLength(shortInterval, interval, totalRounds);
  TimerStage? breakAfter(int round) => pomodoroBreak(
    round,
    shortInterval: shortInterval,
    longInterval: interval,
    totalRounds: totalRounds,
  );
  ({int short, int long}) get breakCounts {
    var short = 0, long = 0;
    for (var round = 1; round <= cycleLength; round++) {
      switch (breakAfter(round)) {
        case TimerStage.shortBreak:
          short++;
        case TimerStage.longBreak:
          long++;
        default:
          break;
      }
    }
    return (short: short, long: long);
  }

  final bool sound, haptics;
  final FeedbackOptions pomodoroFeedback,
      stopwatchFeedback,
      countdownFeedback,
      habitFeedback;
  FeedbackOptions feedbackFor(TimerMode mode) => switch (mode) {
    TimerMode.pomodoro => pomodoroFeedback,
    TimerMode.stopwatch => stopwatchFeedback,
    TimerMode.countdown => countdownFeedback,
  };
  TimingPreferences withFeedback(TimerMode mode, FeedbackOptions value) =>
      copyWith(
        pomodoroFeedback: mode == TimerMode.pomodoro ? value : null,
        stopwatchFeedback: mode == TimerMode.stopwatch ? value : null,
        countdownFeedback: mode == TimerMode.countdown ? value : null,
      );
  final List<int?> presets;
  TimingPreferences copyWith({
    int? focusSeconds,
    int? shortSeconds,
    int? longSeconds,
    int? interval,
    int? shortInterval,
    int? totalRounds,
    int? threshold,
    bool? sound,
    bool? haptics,
    FeedbackOptions? pomodoroFeedback,
    FeedbackOptions? stopwatchFeedback,
    FeedbackOptions? countdownFeedback,
    FeedbackOptions? habitFeedback,
    List<int?>? presets,
  }) => TimingPreferences(
    focusSeconds: focusSeconds ?? this.focusSeconds,
    shortSeconds: shortSeconds ?? this.shortSeconds,
    longSeconds: longSeconds ?? this.longSeconds,
    interval: interval ?? this.interval,
    shortInterval: shortInterval ?? this.shortInterval,
    totalRounds: totalRounds ?? this.totalRounds,
    threshold: threshold ?? this.threshold,
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    pomodoroFeedback: pomodoroFeedback ?? this.pomodoroFeedback,
    stopwatchFeedback: stopwatchFeedback ?? this.stopwatchFeedback,
    countdownFeedback: countdownFeedback ?? this.countdownFeedback,
    habitFeedback: habitFeedback ?? this.habitFeedback,
    presets: presets ?? this.presets,
  );
}
