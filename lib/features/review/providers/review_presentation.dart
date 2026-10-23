import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/time.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';

class ReviewSelection {
  const ReviewSelection({
    required this.anchor,
    this.month = false,
    this.lastViewedDate,
  });
  final DateTime anchor;
  final bool month;
  final String? lastViewedDate;
  DateTime get first =>
      month ? DateTime.utc(anchor.year, anchor.month) : weekStart(anchor);
  DateTime get last => month
      ? DateTime.utc(anchor.year, anchor.month + 1, 0)
      : first.add(const Duration(days: 6));
  ReviewSelection copyWith({
    DateTime? anchor,
    bool? month,
    String? lastViewedDate,
    bool clear = false,
  }) => ReviewSelection(
    anchor: anchor ?? this.anchor,
    month: month ?? this.month,
    lastViewedDate: clear ? null : lastViewedDate ?? this.lastViewedDate,
  );
}

class ReviewPresentation extends Notifier<ReviewSelection> {
  @override
  ReviewSelection build() => ReviewSelection(anchor: ref.read(todayProvider));
  void select(ReviewSelection value) => state = value;
}

final reviewSelectionProvider =
    NotifierProvider<ReviewPresentation, ReviewSelection>(
      ReviewPresentation.new,
    );

class ReviewSummary {
  const ReviewSummary({required this.records, required this.checkins});
  final List<FocusRecordView> records;
  final int checkins;
  num get seconds =>
      records.fold<num>(0, (sum, record) => sum + record.seconds);
}

final reviewSummaryProvider = Provider<ReviewSummary>(
  (ref) {
    final selection = ref.watch(reviewSelectionProvider);
    final from = dayId(selection.first), through = dayId(selection.last);
    bool contains(String date) =>
        date.compareTo(from) >= 0 && date.compareTo(through) <= 0;
    return ReviewSummary(
      records: List.unmodifiable(
        ref.watch(focusRecordsProvider).where((r) => contains(r.date)),
      ),
      checkins: ref
          .watch(habitsProvider)
          .expand((h) => h.dates)
          .where(contains)
          .length,
    );
  },
  dependencies: [reviewSelectionProvider, focusRecordsProvider, habitsProvider],
);
