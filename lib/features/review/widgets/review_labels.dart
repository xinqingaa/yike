import '../../focus/focus.dart';

export '../logic/review_statistics.dart' show recordIdentity;

String modeLabel(TimerMode mode) => const ['番茄钟', '正计时', '倒计时'][mode.index];
