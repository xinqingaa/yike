import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

enum CommonTagTone { neutral, primary, success, warning, error }

/// Read-only classification; selection belongs to FilterBar or PrimaryTabs.
class CommonTag extends StatelessWidget {
  const CommonTag({
    super.key,
    required this.label,
    this.tone = CommonTagTone.neutral,
  });
  final String label;
  final CommonTagTone tone;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final (background, foreground) = switch (tone) {
      CommonTagTone.neutral => (ts.colors.surfaceVariant, ts.colors.onSurface),
      CommonTagTone.primary => (ts.colors.primarySoft, ts.colors.primary),
      CommonTagTone.success => (ts.colors.successSoft, ts.colors.success),
      CommonTagTone.warning => (ts.colors.warningSoft, ts.colors.warning),
      CommonTagTone.error => (ts.colors.errorSoft, ts.colors.error),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ts.radius.xs),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ts.spacing.xs,
          vertical: ts.spacing.xxs,
        ),
        child: Text(
          label,
          style: ts.textStyle.captionStrong.copyWith(color: foreground),
        ),
      ),
    );
  }
}
