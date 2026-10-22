import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/local_value.dart';

import '../../../theme/ts.dart';
import '../action/icon.dart';

/// 对齐 pbwork `TextField` — 官方 [TextField]。
class CommonTextField extends ConsumerStatefulWidget {
  const CommonTextField({
    super.key,
    this.controller,
    this.label,
    this.showLabel = false,
    this.hint,
    this.enabled = true,
    this.obscureText = false,
    this.revealable = false,
    this.errorText,
    this.autofillHints,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final bool showLabel;
  final String? hint;
  final bool enabled;
  final bool obscureText;
  final bool revealable;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  ConsumerState<CommonTextField> createState() => _CommonTextFieldState();
}

class _CommonTextFieldState extends ConsumerState<CommonTextField> {
  final _revealedProvider = localValueProvider(false);

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final revealed = ref.watch(_revealedProvider);
    final hidden = widget.obscureText && !revealed;
    final field = ConstrainedBox(
      constraints: BoxConstraints(minHeight: ts.sizing.controlMd),
      child: Opacity(
        opacity: widget.enabled ? ts.opacity.visible : ts.opacity.disabled,
        child: TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: hidden,
          autofillHints: widget.autofillHints,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: ts.textStyle.content,
          decoration: InputDecoration(
            labelText: null,
            labelStyle: ts.textStyle.caption,
            hintText: widget.hint,
            errorText: widget.errorText,
            filled: true,
            fillColor: widget.showLabel
                ? ts.colors.surface
                : ts.colors.surfaceRecessed,
            border: widget.showLabel ? null : InputBorder.none,
            enabledBorder: widget.showLabel ? null : InputBorder.none,
            focusedBorder: widget.showLabel ? null : InputBorder.none,
            suffixIcon: widget.obscureText && widget.revealable
                ? IconButton(
                    tooltip: revealed ? '隐藏密码' : '显示密码',
                    onPressed: widget.enabled
                        ? () => ref
                              .read(_revealedProvider.notifier)
                              .update((value) => !value)
                        : null,
                    icon: CommonIcon(
                      name: revealed
                          ? CommonIconName.eyeOff
                          : CommonIconName.eye,
                      dimension: ts.sizing.iconMd,
                      color: ts.colors.onSurfaceMuted,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel && widget.label != null) ...[
          Text(widget.label!, style: ts.textStyle.caption),
          SizedBox(height: ts.spacing.sm),
        ],
        field,
      ],
    );
  }
}
