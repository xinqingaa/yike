import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import 'choice_option.dart';

/// 对齐 pbwork `RadioGroup`。默认选中色为 `color.primary`。
/// Resolve color from the contextual theme when overriding its slot.
class CommonRadioGroup<T> extends StatelessWidget {
  const CommonRadioGroup({
    super.key,
    required this.options,
    required this.value,
    this.label,
    this.enabled = true,
    this.onChanged,
    this.color,
  });

  final List<CommonChoiceOption<T>> options;
  final T? value;
  final String? label;
  final bool enabled;
  final ValueChanged<T?>? onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final interactive = enabled && onChanged != null;
    return Opacity(
      opacity: interactive ? ts.opacity.visible : ts.opacity.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label!, style: ts.textStyle.caption),
            SizedBox(height: ts.spacing.sm),
          ],
          RadioGroup<T>(
            groupValue: value,
            onChanged: (next) {
              if (interactive) onChanged!(next);
            },
            child: Column(
              children: [
                for (final opt in options)
                  RadioListTile<T>(
                    value: opt.value,
                    title: Text(opt.label, style: ts.textStyle.content),
                    contentPadding: EdgeInsets.zero,
                    enabled: interactive && opt.enabled,
                    activeColor: color ?? ts.colors.primary,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
