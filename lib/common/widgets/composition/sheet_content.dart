import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';
import '../display/divider.dart';

/// Shared decision row. Layout policy lives here, callbacks belong to the caller.
class CommonDecisionActions extends StatelessWidget {
  const CommonDecisionActions({super.key, required this.actions});
  final List<CommonButton> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    const primary = {
      CommonButtonKind.primary,
      CommonButtonKind.accent,
      CommonButtonKind.danger,
      CommonButtonKind.outlined,
    };
    if (actions.length > 2 ||
        !primary.contains(actions.last.kind) ||
        (actions.length == 2 &&
            !{
              CommonButtonKind.secondary,
              CommonButtonKind.quiet,
            }.contains(actions.first.kind))) {
      throw ArgumentError(
        'Decision actions require one primary action, or secondary/quiet then primary.',
      );
    }
    final ts = TS.of(context);
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: ts.spacing.smPlus),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

/// For the library-owned FlowSheet viewport: one vertical body and fixed footer.
class CommonFlowSheetContent extends StatelessWidget {
  const CommonFlowSheetContent({
    super.key,
    required this.body,
    required this.step,
    required this.stepCount,
    this.actions = const [],
  });
  final Widget body;
  final int step;
  final int stepCount;
  final List<CommonButton> actions;

  @override
  Widget build(BuildContext context) {
    if (stepCount < 1 || step < 0 || step >= stepCount) {
      throw ArgumentError('Flow step is outside its declared range.');
    }
    final ts = TS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: ts.spacing.md),
            child: body,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: ts.spacing.xsPlus),
          child: Semantics(
            label: '第${step + 1}步，共$stepCount步',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < stepCount; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ts.spacing.xsPlus / 2,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(ts.radius.full),
                          color: i == step
                              ? ts.colors.primary
                              : ts.colors.surfaceVariant,
                        ),
                        child: SizedBox(
                          height: ts.sizing.stepDot,
                          width: ts.sizing.stepDot * (i == step ? 2.5 : 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: ts.spacing.sm),
        if (actions.isNotEmpty) const CommonDivider(),
        if (actions.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              ts.spacing.md,
              ts.spacing.smPlus,
              ts.spacing.md,
              0,
            ),
            child: CommonDecisionActions(actions: actions),
          ),
      ],
    );
  }
}
