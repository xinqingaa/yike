import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../common/overlay/app_pop.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';
import '../logic/review_statistics.dart';
import 'review_labels.dart';

String dateWeekLabel(String date) {
  final day = DateTime.parse(date);
  return '${day.month}月${day.day}日 周${const ['一', '二', '三', '四', '五', '六', '日'][day.weekday - 1]}';
}

class ReviewDayTarget extends ConsumerWidget {
  const ReviewDayTarget({
    super.key,
    required this.date,
    required this.card,
    required this.child,
    this.onOpen,
    this.mode,
    this.enabled = true,
    this.focusNode,
    this.shape,
  });
  final String date;
  final AppDataCard card;
  final Widget child;
  final VoidCallback? onOpen;
  final TimerMode? mode;
  final bool enabled;
  final FocusNode? focusNode;
  final OutlinedBorder? shape;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DataCardTarget(
    card: card,
    onShow: () => ref.read(feedbackServiceProvider).select(),
    content: (_) => DayDataCard(
      date: date,
      mode: mode,
      onOpen: onOpen == null
          ? null
          : () async {
              card.close();
              // Let the nonmodal card surrender back/route ownership before the sheet.
              await Future<void>.delayed(Duration.zero);
              onOpen!();
            },
    ),
    builder: (context, show, selected) => CommonPressableSurface(
      focusNode: focusNode,
      onPressed: enabled ? show : null,
      onLongPress: enabled ? show : null,
      shape:
          shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              TS.of(context).pack.id.endsWith('sundial')
                  ? TS.of(context).radius.xs
                  : TS.of(context).radius.full,
            ),
          ),
      child: child,
    ),
  );
}

class DayDataCard extends ConsumerWidget {
  const DayDataCard({super.key, required this.date, this.mode, this.onOpen});
  final String date;
  final TimerMode? mode;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = TS.of(context), day = DateTime.parse(date);
    final metrics = PeriodMetrics(
      ref.watch(focusRecordsProvider),
      day,
      day,
      mode: mode,
    );
    final checkins = ref
        .watch(habitsProvider)
        .where((h) => h.dates.contains(date))
        .length;
    final duration = durationLabel(metrics.seconds, compact: true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(dateWeekLabel(date), style: ts.textStyle.subtitle),
        if (mode != null)
          Text('仅${modeLabel(mode!)}', style: ts.textStyle.caption),
        SizedBox(height: ts.spacing.sm),
        Semantics(
          label:
              '专注 ${durationLabel(metrics.seconds)}，专注次数 ${metrics.sessions}次',
          excludeSemantics: true,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: ts.spacing.xs),
            child: Text(
              '专注 ${metrics.sessions}次 $duration',
              style: ts.textStyle.content,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: ts.spacing.xs),
          child: Text('打卡 $checkins次', style: ts.textStyle.content),
        ),
        if (onOpen != null) ...[
          SizedBox(height: ts.spacing.sm),
          const CommonDivider(),
          CommonButton(
            label: '查看当日记录',
            kind: CommonButtonKind.quiet,
            onPressed: onOpen,
          ),
        ],
      ],
    );
  }
}
