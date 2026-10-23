import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/overlay/app_pop.dart';
import '../../../common/state/local_value.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../providers/review_presentation.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';

String reviewPeriodLabel(ReviewSelection selection) => selection.month
    ? '${selection.first.year} 年 ${selection.first.month} 月'
    : '${selection.first.month}月${selection.first.day}日 – ${selection.last.month == selection.first.month ? '' : '${selection.last.month}月'}${selection.last.day}日';

Future<ReviewSelection?> pickReviewPeriod(ReviewSelection selection) {
  final sheet = AppSheet<ReviewSelection>();
  return sheet.show(
    title: '选择${selection.month ? '月份' : '周次'}',
    child: _PeriodPicker(selection: selection, onSelected: sheet.complete),
  );
}

class _PeriodPicker extends ConsumerStatefulWidget {
  const _PeriodPicker({required this.selection, required this.onSelected});
  final ReviewSelection selection;
  final ValueChanged<ReviewSelection> onSelected;
  @override
  ConsumerState<_PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends ConsumerState<_PeriodPicker> {
  late final _year = localValueProvider(widget.selection.anchor.year);
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context),
        year = ref.watch(_year),
        today = ref.watch(todayProvider);
    final records = ref.watch(focusRecordsProvider);
    final habits = ref.watch(habitsProvider);
    final starts = widget.selection.month
        ? [for (var month = 1; month <= 12; month++) DateTime.utc(year, month)]
        : [
            for (
              var date = weekStart(DateTime.utc(year));
              !date.isAfter(DateTime.utc(year, 12, 31));
              date = date.add(const Duration(days: 7))
            )
              date,
          ];
    final visibleStarts = starts
        .where((date) => !date.isAfter(today))
        .toList()
        .reversed
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CommonIconButton(
              name: CommonIconName.chevronLeft,
              label: '上一年',
              disabled: year <= 1,
              variant: CommonIconButtonVariant.text,
              onPressed: () => ref.read(_year.notifier).set(year - 1),
            ),
            Expanded(
              child: Text(
                '$year 年',
                textAlign: TextAlign.center,
                style: ts.textStyle.subtitle,
              ),
            ),
            CommonIconButton(
              name: CommonIconName.chevronRight,
              label: '下一年',
              disabled: year >= today.year,
              variant: CommonIconButtonVariant.text,
              onPressed: () => ref.read(_year.notifier).set(year + 1),
            ),
          ],
        ),
        SizedBox(height: ts.spacing.sm),
        Flexible(
          child: CommonDataList(
            shrinkWrap: true,
            key: ValueKey('period-list-$year'),
            divided: false,
            surface: CommonDataListSurface.none,
            itemCount: visibleStarts.length,
            itemBuilder: (context, i) {
              final selection = widget.selection.copyWith(
                anchor: visibleStarts[i],
                clear: true,
              );
              final summary = reviewSummaryFor(selection, records, habits);
              return Semantics(
                selected:
                    dayId(selection.first) == dayId(widget.selection.first),
                child: CommonListCell(
                  key: ValueKey('period-${dayId(selection.first)}'),
                  title: reviewPeriodLabel(selection),
                  value: durationLabel(summary.seconds),
                  description: '${summary.checkins} 次打卡',
                  navigation: true,
                  onNavigate: () => widget.onSelected(selection),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
