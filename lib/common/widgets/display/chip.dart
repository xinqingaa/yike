import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

/// 对齐 pbwork Chip `tone`。
enum CommonChipTone { primary, secondary, success, warning, error }

/// 对齐 pbwork `Chip`。
///
/// Display-only when [onTap] is null; interactive when provided.
class CommonChip extends StatelessWidget {
  const CommonChip({
    super.key,
    required this.label,
    this.tone = CommonChipTone.primary,
    this.selected = false,
    this.onTap,
    this.elevated = false,
  });

  final String label;
  final CommonChipTone tone;
  final bool selected;
  final VoidCallback? onTap;
  final bool elevated;

  RoundedRectangleBorder _shape(TS ts) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(ts.radius.sm));

  Color _bg(TS ts) {
    if (selected) return ts.colors.primarySoft;
    switch (tone) {
      case CommonChipTone.primary:
        return ts.colors.primarySoft;
      case CommonChipTone.secondary:
        return ts.colors.secondarySoft;
      case CommonChipTone.success:
        return ts.colors.successSoft;
      case CommonChipTone.warning:
        return ts.colors.warningSoft;
      case CommonChipTone.error:
        return ts.colors.errorSoft;
    }
  }

  Color _fg(TS ts) {
    if (selected) return ts.colors.primary;
    switch (tone) {
      case CommonChipTone.primary:
        return ts.colors.primary;
      case CommonChipTone.secondary:
        return ts.colors.secondary;
      case CommonChipTone.success:
        return ts.colors.success;
      case CommonChipTone.warning:
        return ts.colors.warning;
      case CommonChipTone.error:
        return ts.colors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final labelStyle = ts.textStyle.caption.copyWith(color: _fg(ts));
    final chip = onTap == null
        ? Chip(
            label: Text(label, style: labelStyle),
            backgroundColor: _bg(ts),
            side: BorderSide.none,
            shape: _shape(ts),
            padding: EdgeInsets.symmetric(horizontal: ts.spacing.xs),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )
        : ActionChip(
            label: Text(label, style: labelStyle),
            onPressed: onTap,
            backgroundColor: _bg(ts),
            side: BorderSide.none,
            shape: _shape(ts),
          );
    return Material(
      type: MaterialType.transparency,
      elevation: elevated ? ts.elevation.card : ts.elevation.none,
      borderRadius: BorderRadius.circular(ts.radius.sm),
      child: chip,
    );
  }
}
