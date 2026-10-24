import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/overlay/app_pop.dart';

import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../models/habit_view.dart';
import 'habit_day_target.dart';

/// Year grid for one habit. Layout comes from [CommonYearGrid].
class HabitHeatmapPlot extends ConsumerStatefulWidget {
  const HabitHeatmapPlot({
    super.key,
    required this.weeks,
    required this.habit,
    required this.today,
  });
  final List<List<CommonHeatmapCell>> weeks;
  final HabitViewData habit;
  final String today;

  @override
  ConsumerState<HabitHeatmapPlot> createState() => _HabitHeatmapPlotState();
}

class _HabitHeatmapPlotState extends ConsumerState<HabitHeatmapPlot> {
  final _card = AppDataCard();

  @override
  void dispose() {
    _card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return CommonYearGrid(
      scrollKey: const ValueKey('habit-year-scroll'),
      weeks: widget.weeks,
      onScroll: _card.close,
      cellBuilder: (context, cell, size) => _cell(ts, cell, size),
    );
  }

  Widget _cell(TS ts, CommonHeatmapCell cell, double size) {
    final done = cell.value == 1;
    final before = cell.date.compareTo(widget.habit.created) < 0;
    final future = cell.date.compareTo(widget.today) > 0;
    final archived =
        widget.habit.archivedOn != null &&
        cell.date.compareTo(widget.habit.archivedOn!) >= 0;
    final inactive = !done && (before || future || cell.value == null);
    final status = done
        ? '已完成'
        : before
        ? '创建前'
        : future || cell.value == null
        ? '范围外'
        : archived
        ? '归档期间'
        : '未打卡';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ts.radius.xs),
    );
    Widget graph(bool selected) => CommonHeatmapBlock(
      cellKey: ValueKey('habit-day-${cell.date}'),
      size: size,
      color: habitDayColor(
        ts,
        done: done,
        inactive: inactive,
        archived: archived,
        selected: selected,
      ),
    );
    if (cell.value == null) {
      return Semantics(label: '${cell.date}，$status', child: graph(false));
    }
    return HabitDayTarget(
      habit: widget.habit,
      date: cell.date,
      today: widget.today,
      card: _card,
      builder: (context, show, selected) => Semantics(
        label: '${cell.date}，$status',
        child: CommonPressableSurface(
          onPressed: show,
          onLongPress: show,
          shape: shape,
          child: graph(selected),
        ),
      ),
    );
  }
}

class HabitHeatmapLegend extends StatelessWidget {
  const HabitHeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    const states = ['完成', '未打卡', '归档', '创建前/未来'];
    return Wrap(
      spacing: ts.spacing.md,
      runSpacing: ts.spacing.sm,
      children: [
        for (final state in states)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommonHeatmapBlock(
                size: ts.spacing.smPlus,
                color: _heatColor(ts, states.indexOf(state)),
              ),
              SizedBox(width: ts.spacing.xs),
              Text(state, style: ts.textStyle.micro),
            ],
          ),
      ],
    );
  }
}

Color _heatColor(TS ts, int state) => switch (state) {
  0 => ts.colors.primary,
  1 => ts.heatmapEmpty,
  2 => ts.heatmapArchived,
  _ => ts.heatmapOutside,
};
