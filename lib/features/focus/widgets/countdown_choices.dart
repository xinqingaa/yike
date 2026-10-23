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
    final style = ts.textStyle.numericContent;
    var labelHeight = 0.0;
    for (final seconds in presets) {
      final painter =
          TextPainter(
            text: TextSpan(
              text: durationLabel(seconds, compact: true),
              style: style.copyWith(fontWeight: FontWeight.w600),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 2,
          )..layout(
            maxWidth: math.max(
              1,
              (width - ts.spacing.sm) / 2 - ts.spacing.smPlus * 2,
            ),
          );
      labelHeight = math.max(labelHeight, painter.height);
      painter.dispose();
    }
    final rowHeight = math.max(
      ts.sizing.touch,
      labelHeight + ts.spacing.sm * 2,
    );
    final captionHeight =
        MediaQuery.textScalerOf(context).scale(ts.textStyle.caption.fontSize!) *
        (ts.textStyle.caption.height ?? 1);
    final customHeight = math.max(
      ts.sizing.touch,
      captionHeight * 2 + ts.spacing.sm * 2,
    );
    final rows = (presets.length / 2).ceil();
    return (
      rowHeight: rowHeight,
      customHeight: customHeight,
      height: rows * (rowHeight + ts.spacing.sm) + customHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final style = ts.textStyle.numericContent;
    final layout = metrics(context, availableWidth, presets);
    final rowHeight = layout.rowHeight;
    final custom = !presets.contains(value);
    Widget option(int seconds) {
      final selected = value == seconds;
      return CommonPressableSurface(
        key: ValueKey('countdown-preset-$seconds'),
        selected: selected,
        onPressed: () => onSelected(seconds),
        child: Container(
          height: rowHeight,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: ts.spacing.smPlus),
          decoration: BoxDecoration(
            color: selected ? ts.colors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(ts.radius.md),
          ),
          child: Text(
            durationLabel(seconds, compact: true),
            maxLines: 2,
            textAlign: TextAlign.center,
            style: style.copyWith(
              color: selected ? ts.colors.primary : ts.colors.onSurface,
              fontWeight: selected ? FontWeight.w600 : style.fontWeight,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < presets.length; i += 2) ...[
          if (i > 0) SizedBox(height: ts.spacing.sm),
          Row(
            children: [
              Expanded(child: option(presets[i])),
              SizedBox(width: ts.spacing.sm),
              Expanded(
                child: i + 1 < presets.length
                    ? option(presets[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
        if (presets.isNotEmpty) SizedBox(height: ts.spacing.sm),
        CommonPressableSurface(
          key: const ValueKey('countdown-custom'),
          selected: custom,
          onPressed: onCustom,
          child: Container(
            height: layout.customHeight,
            padding: EdgeInsets.symmetric(
              horizontal: ts.spacing.smPlus,
              vertical: ts.spacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ts.radius.md),
              color: custom ? ts.colors.primarySoft : Colors.transparent,
            ),
            child: Row(
              children: [
                Text('自定义时长', maxLines: 1, style: ts.textStyle.content),
                SizedBox(width: ts.spacing.sm),
                Expanded(
                  child: Text(
                    custom ? durationLabel(value, compact: true) : '设置',
                    maxLines: 2,
                    textAlign: TextAlign.right,
                    style: ts.textStyle.caption,
                  ),
                ),
                SizedBox(width: ts.spacing.xs),
                CommonIcon(
                  name: CommonIconName.chevronRight,
                  dimension: ts.sizing.iconSm,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
