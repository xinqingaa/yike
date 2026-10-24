import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

/// One geometry for every mode; only the utility and action content changes.
class FocusPanelLayout extends StatelessWidget {
  const FocusPanelLayout({
    super.key,
    required this.minimumUtilityHeight,
    this.compactUtility = false,
    required this.dialBuilder,
    required this.utilityBuilder,
    required this.actions,
    required this.storageKey,
  });
  final double Function(double width) minimumUtilityHeight;
  final bool compactUtility;
  final Widget Function(double width) dialBuilder;
  final Widget Function(double width) utilityBuilder;
  final Widget actions;
  final PageStorageKey<String> storageKey;

  /// Keeps the established dial anchor aligned across the three modes.
  static double minimumAccessoryHeight(
    BuildContext context, {
    required bool compact,
  }) {
    final ts = TS.of(context), scaler = MediaQuery.textScalerOf(context);
    final row = math.max(
      ts.sizing.touch,
      scaler.scale(ts.textStyle.numericContent.fontSize!) *
              (ts.textStyle.numericContent.height ?? 1) +
          ts.spacing.sm * 2,
    );
    return row * (compact ? 2 : 3) +
        ts.spacing.xs +
        scaler.scale(ts.textStyle.caption.fontSize!) *
            (ts.textStyle.caption.height ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(0.0, constraints.maxWidth - ts.spacing.lg * 2);
        final top = ts.spacing.lg, gap = ts.spacing.sm;
        final textHeight =
            MediaQuery.textScalerOf(
              context,
            ).scale(ts.textStyle.label.fontSize!) *
            (ts.textStyle.label.height ?? 1);
        final actionRow = math.max(
          ts.sizing.controlLg,
          textHeight * 2 + ts.spacing.xs * 2,
        );
        final actionsHeight = actionRow * 2 + gap;
        final dialFixed =
            top + minimumUtilityHeight(width) + actionsHeight + gap * 3;
        final utilityHeight = compactUtility
            ? ts.sizing.touch
            : minimumUtilityHeight(width);
        final fixed = top + utilityHeight + actionsHeight + gap * 3;
        final preferred = math.min(ts.sizing.plot, width);
        final dialWidth = math.max(
          math.min(preferred, ts.sizing.touch * 4),
          math.min(
            preferred,
            (constraints.maxHeight - dialFixed) / ts.artworkAspectRatio,
          ),
        );
        final height = math.max(
          constraints.maxHeight,
          fixed + dialWidth * ts.artworkAspectRatio,
        );
        return SingleChildScrollView(
          key: storageKey,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ts.spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: top),
                  Center(child: dialBuilder(dialWidth)),
                  SizedBox(height: gap),
                  if (compactUtility)
                    SizedBox(
                      height: utilityHeight,
                      child: utilityBuilder(width),
                    )
                  else
                    Expanded(child: utilityBuilder(width)),
                  SizedBox(height: gap),
                  SizedBox(height: actionsHeight, child: actions),
                  SizedBox(height: gap),
                  if (compactUtility) const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
