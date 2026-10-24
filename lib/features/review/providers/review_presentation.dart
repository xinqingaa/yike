import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/time.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';
import '../models/review_period.dart';
export '../models/review_period.dart';

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
  const ReviewSummary({
    required this.records,
    required this.checkins,
    required this.allRecords,
  });
  final List<FocusRecordView> records, allRecords;
  final int checkins;
  num get seconds =>
      records.fold<num>(0, (sum, record) => sum + record.seconds);
}

ReviewSummary reviewSummaryFor(
  ReviewSelection selection,
  Iterable<FocusRecordView> records,
  Iterable<HabitViewData> habits,
) {
  final from = dayId(selection.first), through = dayId(selection.last);
  bool contains(String date) =>
      date.compareTo(from) >= 0 && date.compareTo(through) <= 0;
  return ReviewSummary(
    allRecords: List.unmodifiable(records.where((r) => contains(r.date))),
    records: List.unmodifiable(
      records.where(
        (r) =>
            contains(r.date) &&
            (selection.mode == null || r.mode == selection.mode),
      ),
    ),
    checkins: habits.expand((h) => h.dates).where(contains).length,
  );
}

final reviewSummaryProvider = Provider<ReviewSummary>(
  (ref) => reviewSummaryFor(
    ref.watch(reviewSelectionProvider),
    ref.watch(focusRecordsProvider),
    ref.watch(habitsProvider),
  ),
  dependencies: [reviewSelectionProvider, focusRecordsProvider, habitsProvider],
);
