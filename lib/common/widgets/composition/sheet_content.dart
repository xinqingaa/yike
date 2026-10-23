import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';

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

/// Optional progress for a linear flow; editing branches normally omit it.
class CommonFlowSheetProgress {
  const CommonFlowSheetProgress({required this.step, required this.total});
  final int step, total;
}

/// For the library-owned FlowSheet viewport: one vertical body and fixed footer.
class CommonFlowSheetContent extends StatelessWidget {
  const CommonFlowSheetContent({
    super.key,
    required this.body,
    this.progress,
    this.actions = const [],
  });
  final Widget body;
  final CommonFlowSheetProgress? progress;
  final List<CommonButton> actions;

  @override
  Widget build(BuildContext context) {
    final step = progress?.step ?? 0;
    final stepCount = progress?.total ?? 1;
    if (progress != null && (stepCount < 1 || step < 0 || step >= stepCount)) {
      throw ArgumentError('Flow step is outside its declared range.');
    }
    final ts = TS.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: ts.spacing.sm),
            child: body,
          ),
        ),
        if (progress != null)
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
        if (actions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: ts.spacing.smPlus),
            child: CommonDecisionActions(actions: actions),
          ),
      ],
    );
  }
}
