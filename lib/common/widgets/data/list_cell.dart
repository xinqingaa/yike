import '../../motion/content_transition.dart';
import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/icon.dart';
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
    final action = disabled
        ? null
        : switchValue != null
        ? (onSwitchChanged == null
              ? null
              : () => onSwitchChanged!(!switchValue!))
        : navigation
        ? onNavigate
        : null;
    final content = Semantics(
      container: true,
      button: navigation,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled ? ts.opacity.disabled : ts.opacity.visible,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: ts.sizing.touch),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ts.spacing.md,
              vertical: switchValue != null
                  ? ts.spacing.xxs
                  : density == CommonDensity.compact
                  ? ts.spacing.xs
                  : ts.spacing.md,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
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
                        MotionExpand(
                          expanded: description != null,
                          child: Text(
                            description ?? '',
                            style: ts.textStyle.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    SizedBox(width: ts.spacing.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * .55,
                      ),
                      child: MotionContent(
                        identity: value,
                        alignment: Alignment.centerRight,
                        child: Text(value!, style: ts.textStyle.caption),
                      ),
                    ),
                  ],
                  if (switchValue != null)
                    CommonSwitch(
                      value: switchValue!,
                      enabled: !disabled && onSwitchChanged != null,
                      onChanged: onSwitchChanged,
                    )
                  else if (navigation)
                    Padding(
                      padding: EdgeInsets.only(left: ts.spacing.sm),
                      child: CommonIcon(
                        name: CommonIconName.chevronRight,
                        dimension: ts.sizing.iconSm,
                        color: ts.colors.onSurfaceMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Tooltip(
      message: navigation ? '打开$title' : title,
      child: InkWell(
        onTap: action,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? ts.colors.primary.withValues(alpha: ts.opacity.pressed)
              : null,
        ),
        child: content,
      ),
    );
  }
}
