import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';

class CountdownChoices extends StatelessWidget {
  const CountdownChoices({
    super.key,
    required this.availableWidth,
    required this.presets,
    required this.selectedIndex,
    required this.onSelected,
    required this.onEdit,
  });
  final double availableWidth;
  final List<int> presets;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onEdit;

  static ({double rowHeight, double customHeight, double height}) metrics(
    BuildContext context,
    double width,
    List<int> presets,
  ) {
    final ts = TS.of(context);
    final painter = TextPainter(
      text: TextSpan(text: '常用', style: ts.textStyle.content),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = math.max(
      ts.sizing.touch,
      painter.height + ts.spacing.sm * 2,
    );
    painter.dispose();
    return (rowHeight: height, customHeight: height, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final layout = metrics(context, availableWidth, presets);
    var minWidth = ts.sizing.touch;
    for (final seconds in presets) {
      final painter = TextPainter(
        text: TextSpan(
          text: durationLabel(seconds, compact: true),
          style: ts.textStyle.numericContent,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      minWidth = math.max(minWidth, painter.width + ts.spacing.sm * 2);
      painter.dispose();
    }
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('countdown-presets-scroll'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < presets.length; i++) ...[
                  if (i > 0) SizedBox(width: ts.spacing.xs),
                  CommonPressableSurface(
                    key: ValueKey('countdown-preset-${presets[i]}'),
                    selected: selectedIndex == i,
                    onPressed: () => onSelected(presets[i]),
                    child: Container(
                      width: math.max(
                        minWidth,
                        (availableWidth -
                                ts.sizing.touch -
                                ts.spacing.sm -
                                ts.spacing.xs *
                                    math.max(0, presets.length - 1)) /
                            math.max(1, presets.length),
                      ),
                      height: layout.rowHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedIndex == i
                            ? ts.colors.primarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(ts.radius.md),
                      ),
                      child: Text(
                        durationLabel(presets[i], compact: true),
                        maxLines: 1,
                        style: ts.textStyle.numericContent.copyWith(
                          color: selectedIndex == i
                              ? ts.colors.primary
                              : ts.colors.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: ts.spacing.xs),
        IconButton(
          key: const ValueKey('countdown-edit'),
          tooltip: '编辑常用倒计时',
          onPressed: onEdit,
          style: IconButton.styleFrom(
            minimumSize: Size.square(ts.sizing.touch),
          ),
          icon: Icon(
            Icons.edit_outlined,
            size: ts.sizing.iconMd,
            color: ts.colors.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}
