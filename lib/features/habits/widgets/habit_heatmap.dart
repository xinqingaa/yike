import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../models/habit_view.dart';

/// A readable year grid. Only viewport position is owned by this widget.
class HabitHeatmapPlot extends StatefulWidget {
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
  State<HabitHeatmapPlot> createState() => _HabitHeatmapPlotState();
}

class _HabitHeatmapPlotState extends State<HabitHeatmapPlot> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final labelHeight =
        MediaQuery.textScalerOf(context).scale(ts.textStyle.micro.fontSize!) *
        (ts.textStyle.micro.height ?? 1);
    final cellSize = math.max(ts.spacing.smPlus, labelHeight);
    final stride = cellSize + ts.spacing.xs;
    final headerHeight = math.max(
      ts.sizing.controlSm,
      labelHeight + ts.spacing.sm,
    );
    final width = widget.weeks.length * stride;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ts.sizing.controlSm,
          child: Column(
            children: [
              SizedBox(height: headerHeight),
              for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
                SizedBox(
                  height: stride,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(label, style: ts.textStyle.micro),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('habit-year-scroll'),
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: Stack(
                      children: [
                        for (var i = 0; i < widget.weeks.length; i++)
                          if (widget.weeks[i].any(
                            (day) => day.date.endsWith('-01'),
                          ))
                            Positioned(
                              left: i * stride,
                              child: Text(
                                '${int.parse(widget.weeks[i].firstWhere((day) => day.date.endsWith('-01')).date.substring(5, 7))}月',
                                style: ts.textStyle.micro,
                              ),
                            ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final week in widget.weeks)
                        SizedBox(
                          width: stride,
                          child: Column(
                            children: [
                              for (final cell in week)
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: ts.spacing.xs,
                                    bottom: ts.spacing.xs,
                                  ),
                                  child: _cell(ts, cell, cellSize),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    return Semantics(
      label: '${cell.date}，$status',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          key: ValueKey('habit-day-${cell.date}'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ts.radius.xs),
            color: _heatColor(
              ts,
              done
                  ? 0
                  : inactive
                  ? 3
                  : archived
                  ? 2
                  : 1,
            ),
            border: MediaQuery.highContrastOf(context)
                ? Border.all(
                    color: done ? ts.colors.primary : ts.colors.outline,
                    width: ts.border.widthHairline,
                  )
                : null,
          ),
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
    return Wrap(
      spacing: ts.spacing.md,
      runSpacing: ts.spacing.sm,
      children: [
        for (final state in ['完成', '未打卡', '归档', '创建前/未来'])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ts.spacing.smPlus,
                height: ts.spacing.smPlus,
                decoration: BoxDecoration(
                  color: _heatColor(
                    ts,
                    ['完成', '未打卡', '归档', '创建前/未来'].indexOf(state),
                  ),
                  borderRadius: BorderRadius.circular(ts.radius.xs),
                  border: MediaQuery.highContrastOf(context)
                      ? Border.all(
                          color: ts.colors.outline,
                          width: ts.border.widthHairline,
                        )
                      : null,
                ),
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
  0 => Color.alphaBlend(
    ts.colors.primary.withValues(alpha: .8),
    ts.colors.surface,
  ),
  1 => ts.colors.primarySoft,
  2 => ts.colors.surfaceVariant,
  _ => ts.colors.onSurfaceMuted.withValues(alpha: .06),
};
