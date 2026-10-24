import 'package:flutter/foundation.dart';
import '../../../common/feedback/feedback_options.dart';

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
    this.round = 1,
    this.laps = const [],
    this.recovered = false,
  });
  final TimerMode mode;
  final TimerStatus status;
  final TimerStage stage;
  final int seconds, target, round;
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
            : '本轮完成'
      : paused
      ? resting
            ? '休息已暂停'
            : '已暂停'
      : ready
      ? mode == TimerMode.countdown
            ? '设置时长'
            : '准备开始'
      : resting
      ? stage == TimerStage.longBreak
            ? '长休息'
            : '短休息'
      : mode == TimerMode.stopwatch
      ? '已计时'
      : '剩余';
  double get progress => mode == TimerMode.countdown
      ? (seconds / target).clamp(0, 1)
      : mode == TimerMode.stopwatch && seconds > 0 && seconds % 3600 == 0
      ? 1
      : ((mode == TimerMode.stopwatch ? seconds % 3600 : seconds) / 3600).clamp(
          0,
          1,
        );
  @override
  bool operator ==(Object other) =>
      other is FocusViewData &&
      mode == other.mode &&
      status == other.status &&
      stage == other.stage &&
      seconds == other.seconds &&
      target == other.target &&
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
    int? round,
    List<int>? laps,
    bool? recovered,
  }) => FocusViewData(
    mode: mode ?? this.mode,
    status: status ?? this.status,
    stage: stage ?? this.stage,
    seconds: seconds ?? this.seconds,
    target: target ?? this.target,
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
    this.focusMinutes = 25,
    this.shortMinutes = 5,
    this.longMinutes = 15,
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
  final int focusMinutes, shortMinutes, longMinutes, interval, threshold;
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
    int? focusMinutes,
    int? shortMinutes,
    int? longMinutes,
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
    focusMinutes: focusMinutes ?? this.focusMinutes,
    shortMinutes: shortMinutes ?? this.shortMinutes,
    longMinutes: longMinutes ?? this.longMinutes,
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
