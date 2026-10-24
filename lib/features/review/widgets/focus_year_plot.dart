import 'package:flutter/material.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/widgets/charts/calendar_dates.dart';
import '../../../common/widgets/charts/year_grid.dart';
import '../../../common/time.dart';
import '../../../theme/ts.dart';
import '../../focus/focus_models.dart';
import 'day_data_card.dart';

class FocusYearPlot extends StatelessWidget {
  const FocusYearPlot({
    super.key,
    required this.records,
    required this.today,
    required this.card,
    this.mode,
  });
  final List<FocusRecordView> records;
  final DateTime today;
  final AppDataCard card;
  final TimerMode? mode;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context),
        first = today.subtract(const Duration(days: 364));
    final totals = <String, num>{};
    for (final r in records) {
      if (mode == null || r.mode == mode) {
        totals.update(r.date, (v) => v + r.seconds, ifAbsent: () => r.seconds);
      }
    }
    final weeks = heatmapWeeks([
      for (var i = 0; i < 365; i++)
        CommonHeatmapDay(
          date: dayId(first.add(Duration(days: i))),
          value: (totals[dayId(first.add(Duration(days: i)))] ?? 0).toDouble(),
        ),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: '最近一年专注，每日专注分为零、30分钟以内、90分钟以内、超过90分钟',
          explicitChildNodes: true,
          child: CommonYearGrid(
            weeks: weeks,
            onScroll: card.close,
            cellBuilder: (context, cell, size) {
              if (cell.value == null) {
                return CommonHeatmapBlock(size: size, color: ts.heatmapOutside);
              }
              return ReviewDayTarget(
                date: cell.date,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ts.radius.xs),
                ),
                card: card,
                mode: mode,
                child: Semantics(
                  label: '${cell.date}，${durationLabel(cell.value!)}',
                  child: CommonHeatmapBlock(
                    size: size,
                    color: _focusDayColor(ts, cell.value!),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: ts.spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(dayId(first), style: ts.textStyle.micro)),
            Expanded(
              child: Text(
                dayId(today),
                style: ts.textStyle.micro,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        SizedBox(height: ts.spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('少', style: ts.textStyle.micro),
            for (final value in [0.0, 1800.0, 5400.0, 5401.0])
              Padding(
                padding: EdgeInsets.only(left: ts.spacing.xs),
                child: CommonHeatmapBlock(
                  size: ts.spacing.smPlus,
                  color: _focusDayColor(ts, value),
                ),
              ),
            SizedBox(width: ts.spacing.xs),
            Text('多', style: ts.textStyle.micro),
          ],
        ),
      ],
    );
  }
}

Color _focusDayColor(TS ts, double seconds) {
  final level = seconds == 0
      ? 0
      : seconds <= 1800
      ? 1
      : seconds <= 5400
      ? 2
      : 3;
  // One hue, equal steps. Zero is the lightest; the top stays short of solid primary.
  return Color.lerp(
    ts.colors.background,
    ts.colors.primary,
    const [.20, .38, .56, .74][level],
  )!;
}
