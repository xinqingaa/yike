import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

/// 对齐 pbwork `Textarea` — 官方多行 [TextField]。
class CommonTextArea extends StatelessWidget {
  const CommonTextArea({
    super.key,
    this.controller,
    this.label,
    this.showLabel = false,
    this.hint,
    this.enabled = true,
    this.rows,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? label;
  final bool showLabel;
  final String? hint;
  final bool enabled;
  final int? rows;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final visibleRows = rows ?? ts.sizing.textareaRows;
    final field = Opacity(
      opacity: enabled ? ts.opacity.visible : ts.opacity.disabled,
      child: TextField(
        controller: controller,
        enabled: enabled,
        minLines: visibleRows,
        maxLines: visibleRows,
        onChanged: onChanged,
        style: ts.textStyle.content,
        decoration: InputDecoration(
          labelText: null,
          labelStyle: ts.textStyle.caption,
          hintText: hint,
          alignLabelWithHint: true,
          filled: true,
          fillColor: showLabel ? ts.colors.surface : ts.colors.surfaceRecessed,
          border: showLabel ? null : InputBorder.none,
          enabledBorder: showLabel ? null : InputBorder.none,
          focusedBorder: showLabel ? null : InputBorder.none,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel && label != null) ...[
          Text(label!, style: ts.textStyle.caption),
          SizedBox(height: ts.spacing.sm),
        ],
        field,
      ],
    );
  }
}
