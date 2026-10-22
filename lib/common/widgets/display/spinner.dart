import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';

/// 对齐 pbwork `Spinner` — 官方 [CircularProgressIndicator]。
class CommonSpinner extends StatelessWidget {
  const CommonSpinner({
    super.key,
    this.label,
    this.size = CommonControlSize.md,
  });

  final String? label;
  final CommonControlSize size;

  double _dim(TS ts) {
    switch (size) {
      case CommonControlSize.sm:
        return ts.sizing.iconSm;
      case CommonControlSize.md:
        return ts.sizing.iconMd;
      case CommonControlSize.lg:
        return ts.sizing.iconLg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final spinner = SizedBox(
      width: _dim(ts),
      height: _dim(ts),
      child: CircularProgressIndicator(
        strokeWidth: ts.sizing.indicatorThickness,
        color: ts.colors.primary,
      ),
    );
    if (label == null) return spinner;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        spinner,
        SizedBox(width: ts.spacing.sm),
        Text(label!, style: ts.textStyle.caption),
      ],
    );
  }
}
