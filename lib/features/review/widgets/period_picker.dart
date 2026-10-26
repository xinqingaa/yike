import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motion/page_transition.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/state/local_value.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../providers/review_presentation.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';

String _two(int value) => value.toString().padLeft(2, '0');
String _monthDay(DateTime date) => '${_two(date.month)}月${_two(date.day)}日';
String reviewPeriodLabel(ReviewSelection selection) => selection.month
    ? '${selection.first.year.toString().padLeft(4, '0')}年${_two(selection.first.month)}月'
    : '${_monthDay(selection.first)} – ${_monthDay(selection.last)}';

Future<ReviewSelection?> pickReviewPeriod(ReviewSelection selection) {
  final sheet = AppSheet<ReviewSelection>();
  return sheet.show(
    showHeader: false,
    material: CommonSurfaceMaterial.glass,
    size: const SheetSizeConfig(height: SheetDimension.fraction(.7)),
    child: _PeriodPicker(
      selection: selection,
      onSelected: sheet.complete,
      onClose: sheet.dismiss,
    ),
  );
}

class _PeriodPicker extends ConsumerStatefulWidget {
  const _PeriodPicker({
    required this.selection,
    required this.onSelected,
    required this.onClose,
  });
  final ReviewSelection selection;
  final ValueChanged<ReviewSelection> onSelected;
  final VoidCallback onClose;
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
    final visible = starts
        .where((date) => !date.isAfter(today))
        .toList()
        .reversed
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: ts.spacing.sm, bottom: ts.spacing.md),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CommonIconButton(
                      name: CommonIconName.chevronLeft,
                      label: '上一年',
                      variant: CommonIconButtonVariant.text,
                      disabled: year <= 1,
                      onPressed: () => ref.read(_year.notifier).set(year - 1),
                    ),
                    Flexible(
                      child: Semantics(
                        label: '选择${widget.selection.month ? '月份' : '周次'}',
                        child: Text(
                          '${year.toString().padLeft(4, '0')}年',
                          textAlign: TextAlign.center,
                          style: ts.textStyle.subtitle,
                        ),
                      ),
                    ),
                    CommonIconButton(
                      name: CommonIconName.chevronRight,
                      label: '下一年',
                      variant: CommonIconButtonVariant.text,
                      disabled: year >= today.year,
                      onPressed: () => ref.read(_year.notifier).set(year + 1),
                    ),
                  ],
                ),
              ),
              CommonIconButton(
                name: CommonIconName.x,
                label: '关闭',
                material: CommonSurfaceMaterial.glass,
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: MotionPage<int>(
            value: year,
            resize: false,
            direction: (before, after) => (after - before).toDouble(),
            child: _PeriodList(
              key: ValueKey('period-list-$year'),
              starts: visible,
              selection: widget.selection,
              onSelected: widget.onSelected,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodList extends ConsumerStatefulWidget {
  const _PeriodList({
    super.key,
    required this.starts,
    required this.selection,
    required this.onSelected,
  });
  final List<DateTime> starts;
  final ReviewSelection selection;
  final ValueChanged<ReviewSelection> onSelected;
  @override
  ConsumerState<_PeriodList> createState() => _PeriodListState();
}

class _PeriodListState extends ConsumerState<_PeriodList> {
  ScrollController? _scroll;
  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final records = ref.watch(focusRecordsProvider),
        habits = ref.watch(habitsProvider);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final title =
            TextPainter(
              text: TextSpan(
                text: widget.selection.month ? '2026年12月' : '12月31日 – 12月31日',
                style: DefaultTextStyle.of(
                  context,
                ).style.merge(ts.textStyle.content),
              ),
              textDirection: Directionality.of(context),
              textScaler: scaler,
              locale: Localizations.maybeLocaleOf(context),
            )..layout(
              maxWidth: math.max(
                1,
                constraints.maxWidth -
                    ts.spacing.md * 2 -
                    ts.sizing.iconMd -
                    ts.spacing.sm,
              ),
            );
        final rowHeight = math.max(
          ts.sizing.touch,
          title.height +
              scaler.scale(ts.textStyle.caption.fontSize!) *
                  (ts.textStyle.caption.height ?? 1) *
                  2 +
              ts.spacing.sm * 2 +
              ts.spacing.xs,
        );
        title.dispose();
        final selectedIndex = widget.starts.indexWhere(
          (date) =>
              dayId(widget.selection.copyWith(anchor: date).first) ==
              dayId(widget.selection.first),
        );
        _scroll ??= ScrollController(
          initialScrollOffset: math.max(0, selectedIndex) * rowHeight,
        );
        return ListView.builder(
          controller: _scroll,
          itemExtent: rowHeight,
          itemCount: widget.starts.length,
          padding: EdgeInsets.only(bottom: ts.spacing.md),
          itemBuilder: (context, index) {
            final selection = widget.selection.copyWith(
              anchor: widget.starts[index],
              clear: true,
            );
            final selected =
                dayId(selection.first) == dayId(widget.selection.first);
            final summary = reviewSummaryFor(selection, records, habits);
            return Semantics(
              selected: selected,
              child: CommonPressableSurface(
                key: ValueKey('period-${dayId(selection.first)}'),
                selected: selected,
                onPressed: () => widget.onSelected(selection),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ts.spacing.md,
                    vertical: ts.spacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? ts.colors.primarySoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(ts.radius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reviewPeriodLabel(selection),
                              style: ts.textStyle.content.copyWith(
                                color: selected
                                    ? ts.colors.primary
                                    : ts.colors.onSurface,
                              ),
                            ),
                            SizedBox(height: ts.spacing.xs),
                            Text(
                              '${durationLabel(summary.seconds)} · ${summary.checkins} 次打卡',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ts.textStyle.caption,
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_rounded,
                          size: ts.sizing.iconMd,
                          color: ts.colors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
