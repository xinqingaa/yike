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
    required this.value,
    required this.onSelected,
    required this.onCustom,
  });
  final double availableWidth;
  final List<int> presets;
  final int value;
  final ValueChanged<int> onSelected;
  final VoidCallback onCustom;

  static ({double rowHeight, double customHeight, double height}) metrics(
    BuildContext context,
    double width,
    List<int> presets,
  ) {
    final ts = TS.of(context);
    final painter = TextPainter(
      text: TextSpan(text: '自定义', style: ts.textStyle.content),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = math.max(
      ts.sizing.touch,
      painter.height + ts.spacing.sm * 2,
    );
    painter.dispose();
    return (
      rowHeight: height,
      customHeight: height,
      height: presets.isEmpty ? height : height * 2 + ts.spacing.xs,
    );
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
    final optionWidth = math.max(
      minWidth,
      (availableWidth - ts.spacing.xs * math.max(0, presets.length - 1)) /
          math.max(1, presets.length),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (presets.isNotEmpty) ...[
          SingleChildScrollView(
            key: const ValueKey('countdown-presets-scroll'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < presets.length; i++) ...[
                  if (i > 0) SizedBox(width: ts.spacing.xs),
                  CommonPressableSurface(
                    key: ValueKey('countdown-preset-${presets[i]}'),
                    selected: value == presets[i],
                    onPressed: () => onSelected(presets[i]),
                    child: Container(
                      width: optionWidth,
                      height: layout.rowHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: value == presets[i]
                            ? ts.colors.primarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(ts.radius.md),
                      ),
                      child: Text(
                        durationLabel(presets[i], compact: true),
                        maxLines: 1,
                        style: ts.textStyle.numericContent.copyWith(
                          color: value == presets[i]
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
          SizedBox(height: ts.spacing.xs),
        ],
        CommonButton(
          key: const ValueKey('countdown-custom'),
          label: '自定义',
          kind: CommonButtonKind.quiet,
          onPressed: onCustom,
        ),
      ],
    );
  }
}
