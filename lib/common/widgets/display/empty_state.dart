import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';
import '../action/icon.dart';

/// 对齐 pbwork `EmptyState`。
class CommonEmptyState extends StatelessWidget {
  const CommonEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = CommonIconName.inbox,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? description;
  final CommonIconName icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ts.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ts.sizing.avatarLg,
              height: ts.sizing.avatarLg,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ts.colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: CommonIcon(
                name: icon,
                dimension: ts.sizing.iconLg,
                color: ts.colors.primary,
              ),
            ),
            SizedBox(height: ts.spacing.smPlus),
            Text(
              title,
              style: ts.textStyle.subtitle,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              SizedBox(height: ts.spacing.sm),
              Text(
                description!,
                style: ts.textStyle.content.copyWith(
                  color: ts.colors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              SizedBox(height: ts.spacing.sm),
              CommonButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
