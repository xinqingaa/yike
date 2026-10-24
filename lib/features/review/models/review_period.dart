import '../../../common/time.dart';
import '../../focus/focus_models.dart';

class ReviewSelection {
  const ReviewSelection({
    required this.anchor,
    this.month = false,
    this.lastViewedDate,
    this.mode,
  });
  final DateTime anchor;
  final bool month;
  final String? lastViewedDate;
  final TimerMode? mode;
  DateTime get first =>
      month ? DateTime.utc(anchor.year, anchor.month) : weekStart(anchor);
  DateTime get last => month
      ? DateTime.utc(anchor.year, anchor.month + 1, 0)
      : first.add(const Duration(days: 6));
  ReviewSelection shift(int amount) => copyWith(
    anchor: month
        ? DateTime.utc(anchor.year, anchor.month + amount)
        : anchor.add(Duration(days: amount * 7)),
    clear: true,
  );
  ReviewSelection copyWith({
    DateTime? anchor,
    bool? month,
    String? lastViewedDate,
    bool clear = false,
    TimerMode? mode,
    bool clearMode = false,
  }) => ReviewSelection(
    anchor: anchor ?? this.anchor,
    month: month ?? this.month,
    lastViewedDate: clear ? null : lastViewedDate ?? this.lastViewedDate,
    mode: clearMode ? null : mode ?? this.mode,
  );
}
