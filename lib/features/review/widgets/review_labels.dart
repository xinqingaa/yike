import '../../focus/focus.dart';

String recordIdentity(FocusRecordView record) => record.sessionId.isEmpty
    ? '${record.date}/${record.time}/${record.mode}'
    : record.sessionId;

String modeLabel(TimerMode mode) => const ['番茄钟', '正计时', '倒计时'][mode.index];
