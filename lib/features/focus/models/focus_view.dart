import 'package:flutter/foundation.dart';
import '../../../common/feedback/feedback_options.dart';

const maxFocusSeconds = 3599;
const fullDialSeconds = 3600;

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
  });
  final TimerMode mode;
  final TimerStatus status;
  final TimerStage stage;
  final int seconds, target, round, scaleSeconds;
  final List<int> laps;
  final bool recovered;
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
    this.shortSeconds = 30,
    this.longSeconds = 900,
    this.interval = 4,
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
