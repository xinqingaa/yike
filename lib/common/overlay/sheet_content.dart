import 'package:flutter/material.dart';

import '../../theme/ts.dart';
import '../widgets/display/divider.dart';

/// Scrollable body and fixed actions inside the shared sheet insets.
class AppSheetContent extends StatelessWidget {
  const AppSheetContent({
    super.key,
    required this.body,
    this.actions,
    this.expand = false,
    this.showDivider = false,
  });
  final Widget body;
  final Widget? actions;
  final bool expand, showDivider;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          fit: expand ? FlexFit.tight : FlexFit.loose,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(0, ts.spacing.sm, 0, ts.spacing.md),
            child: body,
          ),
        ),
        if (actions != null && showDivider) const CommonDivider(),
        if (actions != null)
          Padding(
            padding: EdgeInsets.fromLTRB(0, ts.spacing.smPlus, 0, 0),
            child: actions!,
          ),
      ],
    );
  }
}
