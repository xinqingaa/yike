import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

/// 对齐 pbwork `Divider` — 官方 [Divider]。
class CommonDivider extends StatelessWidget {
  const CommonDivider({super.key, this.label, this.inset = false});

  final String? label;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final divider = Divider(
      color: ts.colors.divider,
      height: ts.border.widthHairline,
      thickness: ts.border.widthHairline,
      indent: inset ? ts.spacing.md : 0,
      endIndent: inset ? ts.spacing.md : 0,
    );
    if (label == null) return divider;
    return Row(
      children: [
        Expanded(child: divider),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ts.spacing.sm),
          child: Text(label!, style: ts.textStyle.caption),
        ),
        Expanded(child: divider),
      ],
    );
  }
}
