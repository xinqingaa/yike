import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../common/time.dart';
import '../../../theme/ts.dart';
import 'calendar_dates.dart';

/// Shared year geometry; the caller owns values, inspection, and date semantics.
/// Borderless rounded cell. [cellKey] stays on the painted box for tests.
class CommonHeatmapBlock extends StatelessWidget {
  const CommonHeatmapBlock({
    super.key,
    required this.size,
    required this.color,
    this.cellKey,
  });
  final double size;
  final Color color;
  final Key? cellKey;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        key: cellKey,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(ts.radius.xs),
        ),
      ),
    );
  }
}

class CommonYearGrid extends StatefulWidget {
  const CommonYearGrid({
    super.key,
    required this.weeks,
    required this.cellBuilder,
    this.onScroll,
    this.scrollKey,
  });
  final List<List<CommonHeatmapCell>> weeks;
  final Widget Function(BuildContext, CommonHeatmapCell, double) cellBuilder;
  final VoidCallback? onScroll;
  final Key? scrollKey;
  @override
  State<CommonYearGrid> createState() => _CommonYearGridState();
}

class _CommonYearGridState extends State<CommonYearGrid> {
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
    final ts = TS.of(context),
        labelHeight =
            MediaQuery.textScalerOf(
              context,
            ).scale(ts.textStyle.micro.fontSize!) *
            (ts.textStyle.micro.height ?? 1);
    final cell = math.max(ts.spacing.smPlus, labelHeight),
        stride = cell + ts.spacing.xs,
        header = math.max(ts.sizing.controlSm, labelHeight + ts.spacing.sm);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: ts.sizing.controlSm,
          child: Column(
            children: [
              SizedBox(height: header),
              for (final day in weekdayLabels)
                SizedBox(
                  height: stride,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(day, style: ts.textStyle.micro),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) widget.onScroll?.call();
              return false;
            },
            child: SingleChildScrollView(
              key: widget.scrollKey,
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: widget.weeks.length * stride,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: header,
                      child: Stack(
                        children: [
                          for (var i = 0; i < widget.weeks.length; i++)
                            if (widget.weeks[i].any(
                              (c) => c.date.endsWith('-01'),
                            ))
                              Positioned(
                                left: i * stride,
                                child: Text(
                                  '${int.parse(widget.weeks[i].firstWhere((c) => c.date.endsWith('-01')).date.substring(5, 7))}月',
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
                                for (final day in week)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      right: ts.spacing.xs,
                                      bottom: ts.spacing.xs,
                                    ),
                                    child: widget.cellBuilder(
                                      context,
                                      day,
                                      cell,
                                    ),
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
        ),
      ],
    );
  }
}
