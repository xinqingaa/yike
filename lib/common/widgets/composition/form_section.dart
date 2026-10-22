import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';

/// Target-only 表单组合壳；不占用 Producer componentId。
class CommonFormSection extends StatelessWidget {
  const CommonFormSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.actionLabel,
    this.onAction,
    this.showRequiredMark = false,
  });

  final String title;
  final String? description;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showRequiredMark;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: ts.textStyle.subtitle),
                      ),
                      if (showRequiredMark) ...[
                        SizedBox(width: ts.spacing.xs),
                        Text(
                          '必填',
                          style: ts.textStyle.caption.copyWith(
                            color: ts.colors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (description != null) ...[
                    SizedBox(height: ts.spacing.xxs),
                    Text(description!, style: ts.textStyle.caption),
                  ],
                ],
              ),
            ),
            if (actionLabel != null)
              CommonButton(
                label: actionLabel!,
                kind: CommonButtonKind.quiet,
                size: CommonControlSize.sm,
                onPressed: onAction,
              ),
          ],
        ),
        SizedBox(height: ts.spacing.sm),
        ...children,
      ],
    );
  }
}
