import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/icon.dart';
import '../action/icon_button.dart';
import '../composition/density.dart';
import '../input/switch_control.dart';

class CommonListCell extends StatelessWidget {
  const CommonListCell({
    super.key,
    required this.title,
    this.description,
    this.value,
    this.leading,
    this.navigation = false,
    this.onNavigate,
    this.switchValue,
    this.onSwitchChanged,
    this.disabled = false,
    this.density = CommonDensity.regular,
  });
  final String title;
  final String? description;
  final String? value;
  final Widget? leading;
  final bool navigation;
  final VoidCallback? onNavigate;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final bool disabled;
  final CommonDensity density;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Semantics(
      container: true,
      child: Opacity(
        opacity: disabled ? ts.opacity.disabled : ts.opacity.visible,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: ts.sizing.touch),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ts.spacing.md,
              vertical: density == CommonDensity.compact
                  ? ts.spacing.xs
                  : ts.spacing.md,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: ts.spacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: ts.textStyle.content),
                      if (description != null)
                        Text(description!, style: ts.textStyle.caption),
                    ],
                  ),
                ),
                if (value != null) ...[
                  SizedBox(width: ts.spacing.sm),
                  Text(value!, style: ts.textStyle.caption),
                ],
                if (switchValue != null)
                  CommonSwitch(
                    value: switchValue!,
                    enabled: !disabled,
                    onChanged: onSwitchChanged,
                  )
                else if (navigation)
                  CommonIconButton(
                    name: CommonIconName.chevronRight,
                    label: '打开$title',
                    disabled: disabled,
                    variant: CommonIconButtonVariant.text,
                    onPressed: onNavigate,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
