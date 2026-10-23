import 'package:flutter/material.dart';

import '../../../common/time.dart';
import '../../../common/motion/motion_list.dart';
import '../../../theme/ts.dart';
import '../models/focus_view.dart';

class LapList extends StatelessWidget {
  const LapList({super.key, required this.value, required this.compact});
  final FocusViewData value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final fontHeight =
        MediaQuery.textScalerOf(
          context,
        ).scale(ts.textStyle.numericContent.fontSize!) *
        (ts.textStyle.numericContent.height ?? 1);
    final rowHeight = (fontHeight + ts.spacing.sm * 2).clamp(
      ts.sizing.touch,
      double.infinity,
    );
    Widget columns(
      String label,
      String lap,
      String total, {
      int? index,
      bool current = false,
      bool header = false,
    }) {
      final style = header ? ts.textStyle.caption : ts.textStyle.numericContent;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              key: index == null ? null : ValueKey('lap-label-$index'),
              style: ts.textStyle.caption.copyWith(
                color: current ? ts.colors.primary : ts.colors.onSurfaceMuted,
              ),
            ),
          ),
          SizedBox(width: ts.spacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              lap,
              key: index == null ? null : ValueKey('lap-duration-$index'),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          SizedBox(width: ts.spacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              total,
              key: index == null ? null : ValueKey('lap-total-$index'),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ts.spacing.xs),
          child: columns('圈次', '单圈', '累计', header: true),
        ),
        SizedBox(height: ts.spacing.xs),
        SizedBox(
          height: rowHeight * (compact ? 2 : 3),
          child: MotionList<int>(
            key: const ValueKey('lap-scroll'),
            items: [for (var n = value.laps.length + 1; n > 0; n--) n],
            identity: (number) => number,
            itemBuilder: (context, number) {
              final current = number == value.laps.length + 1;
              final total = current ? value.seconds : value.laps[number - 1];
              final previous = number > 1 ? value.laps[number - 2] : 0;
              return Container(
                key: ValueKey('lap-row-$number'),
                constraints: BoxConstraints(minHeight: rowHeight),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current ? ts.colors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(ts.radius.sm),
                ),
                padding: EdgeInsets.symmetric(horizontal: ts.spacing.xs),
                child: columns(
                  current
                      ? '${value.paused ? '暂停' : '当前'} · $number'
                      : '$number',
                  timerDigits(total - previous),
                  timerDigits(total),
                  index: number,
                  current: current,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
