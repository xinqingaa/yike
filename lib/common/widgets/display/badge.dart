import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

enum CommonBadgeTone { primary, error, success, warning }

/// 只读数量、状态或严重度徽标。
class CommonBadge extends StatelessWidget {
  const CommonBadge({
    super.key,
    required this.label,
    this.tone = CommonBadgeTone.error,
  });

  final String label;
  final CommonBadgeTone tone;

  Color _background(TS ts) => switch (tone) {
    CommonBadgeTone.primary => ts.colors.primary,
    CommonBadgeTone.error => ts.colors.error,
    CommonBadgeTone.success => ts.colors.success,
    CommonBadgeTone.warning => ts.colors.warning,
  };

  Color _foreground(TS ts) => switch (tone) {
    CommonBadgeTone.primary => ts.colors.onPrimary,
    CommonBadgeTone.error => ts.colors.onError,
    CommonBadgeTone.success => ts.colors.onSuccess,
    CommonBadgeTone.warning => ts.colors.onWarning,
  };

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ts.spacing.sm,
        vertical: ts.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: _background(ts),
        borderRadius: BorderRadius.circular(ts.radius.full),
      ),
      child: Text(
        label,
        style: ts.textStyle.captionStrong.copyWith(color: _foreground(ts)),
      ),
    );
  }
}
