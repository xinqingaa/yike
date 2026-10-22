import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

enum CommonLabelPosition { start, end }

/// 对齐 pbwork `Switch`。默认开启色为 `color.primary`。
/// Resolve activeColor from the contextual theme when overriding its slot.
class CommonSwitch extends StatelessWidget {
  const CommonSwitch({
    super.key,
    required this.value,
    this.label,
    this.enabled = true,
    this.onChanged,
    this.activeColor,
    this.labelPosition = CommonLabelPosition.end,
  });

  final bool value;
  final String? label;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final CommonLabelPosition labelPosition;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final control = label == null
        ? Switch(
            value: value,
            onChanged: enabled && onChanged != null ? onChanged : null,
            activeThumbColor: ts.colors.surface,
            activeTrackColor: activeColor ?? ts.colors.primary,
            inactiveThumbColor: ts.colors.surface,
            inactiveTrackColor: ts.colors.outline,
          )
        : SwitchListTile(
            value: value,
            onChanged: enabled && onChanged != null ? onChanged : null,
            title: Text(label!, style: ts.textStyle.content),
            controlAffinity: labelPosition == CommonLabelPosition.start
                ? ListTileControlAffinity.trailing
                : ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: ts.colors.surface,
            activeTrackColor: activeColor ?? ts.colors.primary,
            inactiveThumbColor: ts.colors.surface,
            inactiveTrackColor: ts.colors.outline,
          );
    return Opacity(
      opacity: enabled ? ts.opacity.visible : ts.opacity.disabled,
      child: control,
    );
  }
}
