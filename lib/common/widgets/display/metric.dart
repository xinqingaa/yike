import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

class CommonMetric extends StatelessWidget {
  const CommonMetric({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.change,
  });
  final String label;
  final Object value;
  final String? unit;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final delta = change;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: ts.textStyle.caption),
        SizedBox(height: ts.spacing.sm),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: ts.spacing.sm,
          children: [
            Text('$value', style: ts.textStyle.numericDisplay),
            if (unit != null) Text(unit!, style: ts.textStyle.caption),
          ],
        ),
        if (delta != null && delta.isFinite) ...[
          SizedBox(height: ts.spacing.sm),
          Text(
            delta == 0 ? '持平' : '${delta > 0 ? '+' : ''}$delta',
            style: ts.textStyle.caption.copyWith(
              color: delta == 0
                  ? ts.colors.onSurfaceMuted
                  : delta > 0
                  ? ts.colors.success
                  : ts.colors.error,
            ),
          ),
        ],
      ],
    );
  }
}
