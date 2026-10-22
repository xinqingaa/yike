import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

/// 对齐 pbwork `Checkbox`。默认选中色为 `color.primary`。
/// Instance color slots are resolved from the caller’s contextual theme.
class CommonCheckbox extends StatelessWidget {
  const CommonCheckbox({
    super.key,
    required this.value,
    this.label,
    this.enabled = true,
    this.onChanged,
    this.selectedColor,
    this.uncheckedBorderColor,
  });

  final bool value;
  final String? label;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Color? selectedColor;
  final Color? uncheckedBorderColor;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final box = Checkbox(
      value: value,
      onChanged: enabled && onChanged != null
          ? (next) => onChanged!(next ?? false)
          : null,
      activeColor: selectedColor ?? ts.colors.primary,
      checkColor: ts.colors.onPrimary,
      side: BorderSide(
        color: uncheckedBorderColor ?? ts.colors.outline,
        width: ts.border.widthHairline,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ts.radius.xs),
      ),
    );
    if (label == null) {
      return Opacity(
        opacity: enabled ? ts.opacity.visible : ts.opacity.disabled,
        child: box,
      );
    }
    return Opacity(
      opacity: enabled ? ts.opacity.visible : ts.opacity.disabled,
      child: CheckboxListTile(
        value: value,
        onChanged: enabled && onChanged != null
            ? (next) => onChanged!(next ?? false)
            : null,
        title: Text(label!, style: ts.textStyle.content),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        activeColor: selectedColor ?? ts.colors.primary,
        checkColor: ts.colors.onPrimary,
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ts.radius.xs),
        ),
        side: BorderSide(
          color: uncheckedBorderColor ?? ts.colors.outline,
          width: ts.border.widthHairline,
        ),
      ),
    );
  }
}
