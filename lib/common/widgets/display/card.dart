import 'package:flutter/material.dart';

import '../../../theme/ts.dart';

enum CommonCardSemanticRole { section, card, summary }

/// 只拥有 surface；业务内容和操作由 [child] 自己定义。
class CommonCard extends StatelessWidget {
  const CommonCard({
    super.key,
    required this.child,
    this.elevated = false,
    this.padding,
    this.semanticRole = CommonCardSemanticRole.section,
  });

  final Widget child;
  final bool elevated;
  final EdgeInsetsGeometry? padding;
  final CommonCardSemanticRole semanticRole;

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Semantics(
      container: true,
      child: Card(
        color: ts.colors.surface,
        elevation: elevated ? ts.elevation.card : ts.elevation.none,
        shadowColor: ts.colors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ts.radius.lg),
          side: ts.border.defaultBorder,
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.all(ts.spacing.md),
          child: child,
        ),
      ),
    );
  }
}
