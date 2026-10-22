import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

/// 对齐 pbwork `ProgressIndicator` — 官方 [LinearProgressIndicator]。
class CommonProgress extends StatelessWidget {
  const CommonProgress({super.key, this.value, this.label});

  /// `null` = indeterminate。
  final double? value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: ts.textStyle.caption.copyWith(color: ts.colors.onSurface),
          ),
          SizedBox(height: ts.spacing.xsPlus),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(ts.radius.full),
          child: LinearProgressIndicator(
            value: value == null
                ? null
                : value!.isFinite
                ? (value! / 100).clamp(0.0, 1.0)
                : 0.0,
            minHeight: ts.sizing.progressTrack,
            color: ts.colors.primary,
            backgroundColor: ts.colors.primarySoft,
          ),
        ),
      ],
    );
  }
}
