import '../../../common/motion/content_transition.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../models/focus_view.dart';
import 'countdown_choices.dart';

/// The setup and session share one footprint, including when the page scrolls.
class CountdownUtility extends StatelessWidget {
  const CountdownUtility({
    super.key,
    required this.value,
    required this.preferences,
    required this.availableWidth,
    required this.onSelected,
    required this.onCustom,
    required this.onRecovery,
  });
  final FocusViewData value;
  final TimingPreferences preferences;
  final double availableWidth;
  final ValueChanged<int> onSelected;
  final VoidCallback onCustom, onRecovery;

  static double heightFor(
    BuildContext context,
    double width,
    List<int> presets,
  ) {
    final ts = TS.of(context);
    final captionHeight =
        MediaQuery.textScalerOf(context).scale(ts.textStyle.caption.fontSize!) *
        (ts.textStyle.caption.height ?? 1);
    return math.max(
      CountdownChoices.metrics(context, width, presets).height,
      ts.sizing.controlMd + ts.spacing.sm + captionHeight * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return SizedBox(
      height: heightFor(
        context,
        availableWidth,
        preferences.presets.whereType<int>().toList(),
      ),
      child: MotionContent(
        identity: value.ready,
        resize: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Visibility(
              visible: value.ready,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: CountdownChoices(
                availableWidth: availableWidth,
                presets: preferences.presets.whereType<int>().toList(),
                value: value.target,
                onSelected: onSelected,
                onCustom: onCustom,
              ),
            ),
            if (!value.ready)
              Positioned.fill(
                child: Center(
                  child: MotionContent(
                    identity: (value.status, value.recovered),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value.finished
                              ? preferences.sound &&
                                        preferences.countdownFeedback.sound
                                    ? '提示音已开启'
                                    : '提示音已关闭'
                              : '本次 ${durationLabel(value.target)}',
                          textAlign: TextAlign.center,
                          style: ts.textStyle.caption,
                        ),
                        if (value.paused && value.recovered) ...[
                          SizedBox(height: ts.spacing.sm),
                          CommonButton(
                            label: '查看恢复选项',
                            kind: CommonButtonKind.quiet,
                            onPressed: onRecovery,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
