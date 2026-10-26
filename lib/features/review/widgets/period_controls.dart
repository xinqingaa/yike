import 'package:flutter/material.dart';
import '../../../common/widgets.dart';
import '../../../common/widgets/yike/layout.dart';
import '../../../theme/ts.dart';
import '../models/review_period.dart';
import 'period_picker.dart';

class ReviewPeriodControls extends StatelessWidget {
  const ReviewPeriodControls({
    super.key,
    required this.selection,
    required this.today,
    required this.onChanged,
  });
  final ReviewSelection selection;
  final DateTime today;
  final ValueChanged<ReviewSelection> onChanged;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final current = !selection.last.isBefore(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: ts.sizing.controlSm * 2 + ts.spacing.sm,
              child: YikeSelectionBar(
                size: CommonPrimaryTabsSize.sm,
                items: const [
                  CommonTabItem(value: 'week', label: '周'),
                  CommonTabItem(value: 'month', label: '月'),
                ],
                value: selection.month ? 'month' : 'week',
                onSelected: (value) => onChanged(
                  selection.copyWith(
                    month: value == 'month',
                    anchor: selection.lastViewedDate == null
                        ? (current ? today : selection.anchor)
                        : DateTime.parse(selection.lastViewedDate!),
                    clear: true,
                  ),
                ),
              ),
            ),
            const Spacer(),
            CommonButton(
              key: const ValueKey('review-current-period'),
              label: selection.month ? '本月' : '本周',
              kind: CommonButtonKind.secondary,
              size: CommonControlSize.sm,
              shape: CommonButtonShape.pill,
              disabled: current,
              onPressed: () =>
                  onChanged(selection.copyWith(anchor: today, clear: true)),
            ),
          ],
        ),
        SizedBox(height: ts.spacing.sm),
        Row(
          children: [
            CommonIconButton(
              name: CommonIconName.chevronLeft,
              label: '上一期',
              variant: CommonIconButtonVariant.text,
              onPressed: () => onChanged(selection.shift(-1)),
            ),
            Expanded(
              child: CommonPressableSurface(
                key: const ValueKey('review-period-picker'),
                onPressed: () async {
                  final next = await pickReviewPeriod(selection);
                  if (next != null && context.mounted) onChanged(next);
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: ts.sizing.touch),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          reviewPeriodLabel(selection),
                          textAlign: TextAlign.center,
                          style: ts.textStyle.captionStrong,
                        ),
                      ),
                      SizedBox(width: ts.spacing.xs),
                      CommonIcon(
                        name: CommonIconName.chevronDown,
                        dimension: ts.sizing.iconSm,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CommonIconButton(
              name: CommonIconName.chevronRight,
              label: '下一期',
              disabled: current,
              variant: CommonIconButtonVariant.text,
              onPressed: () => onChanged(selection.shift(1)),
            ),
          ],
        ),
      ],
    );
  }
}
