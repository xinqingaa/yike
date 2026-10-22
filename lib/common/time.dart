import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'clock.dart';

String dayId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
DateTime weekStart(DateTime date) =>
    dayOnly(date).subtract(Duration(days: date.weekday - 1));
String timerDigits(int seconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}'
      : '${two(seconds ~/ 60)}:${two(seconds % 60)}';
}

String durationLabel(num value, {bool compact = false}) {
  final seconds = value.floor();
  if (value > 0 && value < 1) {
    final fraction = value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$fraction${compact ? '秒' : ' 秒'}';
  }
  if (seconds == 0) return '0 分钟';
  final parts = <String>[];
  if (seconds >= 3600) parts.add('${seconds ~/ 3600}${compact ? '小时' : ' 小时'}');
  if (seconds ~/ 60 % 60 > 0) {
    parts.add('${seconds ~/ 60 % 60}${compact ? '分' : ' 分钟'}');
  }
  if (seconds % 60 > 0) parts.add('${seconds % 60}${compact ? '秒' : ' 秒'}');
  return parts.join(compact ? '' : ' ');
}

final todayProvider = Provider<DateTime>(
  (ref) => dayOnly(ref.watch(clockPulseProvider)),
);
