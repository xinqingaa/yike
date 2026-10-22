/// UTC date-only arithmetic. No component reads the system clock.
DateTime? parseCalendarDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final date = DateTime.tryParse('${value}T00:00:00Z');
  return date != null && calendarDayId(date) == value ? date : null;
}

String calendarDayId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime? parseCalendarMonth(String value) => parseCalendarDay('$value-01');

String shiftCalendarMonth(String month, int offset) {
  final first = parseCalendarMonth(month);
  if (first == null) throw ArgumentError.value(month, 'month');
  return calendarDayId(
    DateTime.utc(first.year, first.month + offset),
  ).substring(0, 7);
}

class CommonHeatmapDay {
  const CommonHeatmapDay({required this.date, required this.value});
  final String date;
  final double value;
}

class CommonHeatmapCell {
  const CommonHeatmapCell({required this.date, required this.value});
  final String date;
  final double? value;
}

List<List<CommonHeatmapCell>> heatmapWeeks(List<CommonHeatmapDay> input) {
  final values = {
    for (final day in input)
      if (parseCalendarDay(day.date) != null) day.date: day.value,
  };
  final dates = values.keys.toList()..sort();
  if (dates.isEmpty) return const [];
  final first = parseCalendarDay(dates.first)!;
  final limit = calendarDayId(first.add(const Duration(days: 365)));
  final last = dates.last.compareTo(limit) < 0 ? dates.last : limit;
  var cursor = first.subtract(Duration(days: first.weekday - DateTime.monday));
  final lastDate = parseCalendarDay(last)!;
  final end = lastDate.add(Duration(days: DateTime.sunday - lastDate.weekday));
  final weeks = <List<CommonHeatmapCell>>[];
  while (!cursor.isAfter(end)) {
    final week = <CommonHeatmapCell>[];
    for (var weekday = 0; weekday < 7; weekday++) {
      final date = calendarDayId(cursor);
      final raw = values[date];
      week.add(
        CommonHeatmapCell(
          date: date,
          value: date.compareTo(last) > 0 || raw == null
              ? null
              : raw.isFinite
              ? raw.clamp(0, double.infinity)
              : 0,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    weeks.add(List.unmodifiable(week));
  }
  return List.unmodifiable(weeks);
}
