import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import 'calendar_dates.dart';

export 'calendar_dates.dart' show CommonHeatmapDay, CommonHeatmapCell;
export 'year_grid.dart' show CommonHeatmapBlock, CommonYearGrid;

typedef CommonHeatmapPlotBuilder =
    Widget Function(
      BuildContext context,
      List<List<CommonHeatmapCell>> weeks,
      double maximum,
    );

/// Week geometry, label, and semantics. The year plot is supplied by [plotBuilder].
class CommonHeatmap extends StatefulWidget {
  const CommonHeatmap({
    super.key,
    required this.days,
    this.label = '每日完成记录',
    this.showLabel = true,
    this.plotBuilder,
    this.legend,
  });
  final List<CommonHeatmapDay> days;
  final String label;
  final bool showLabel;
  final CommonHeatmapPlotBuilder? plotBuilder;
  final Widget? legend;

  @override
  State<CommonHeatmap> createState() => _CommonHeatmapState();
}

class _CommonHeatmapState extends State<CommonHeatmap> {
  late List<List<CommonHeatmapCell>> _weeks;
  late double _maximum;
  void _prepare() {
    _weeks = heatmapWeeks(widget.days);
    _maximum = widget.days
        .where((day) => day.value.isFinite)
        .fold(1.0, (maximum, day) => math.max(maximum, day.value));
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant CommonHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.days, oldWidget.days)) _prepare();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Semantics(
      container: !widget.showLabel,
      explicitChildNodes: true,
      label: widget.showLabel ? null : widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showLabel) ...[
            Text(widget.label, style: ts.textStyle.label),
            SizedBox(height: ts.spacing.sm),
          ],
          if (_weeks.isEmpty)
            Text('暂无数据', style: ts.textStyle.caption)
          else if (widget.plotBuilder != null)
            widget.plotBuilder!(context, _weeks, _maximum),
          if (widget.legend != null) ...[
            SizedBox(height: ts.spacing.sm),
            widget.legend!,
          ],
        ],
      ),
    );
  }
}
