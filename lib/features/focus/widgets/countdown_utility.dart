import '../../../common/motion/content_transition.dart';

import 'package:flutter/material.dart';

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
    required this.selectedIndex,
    required this.onSelected,
    required this.onEdit,
    required this.onRecovery,
  });
  final FocusViewData value;
  final TimingPreferences preferences;
  final double availableWidth;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onEdit, onRecovery;

  static double heightFor(
    BuildContext context,
    double width,
    List<int> presets,
  ) {
    return CountdownChoices.metrics(context, width, presets).height;
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
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                onEdit: onEdit,
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
