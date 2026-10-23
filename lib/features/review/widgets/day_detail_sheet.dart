import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/state/local_value.dart';
import '../../../common/time.dart';
import '../../../common/widgets.dart';
import '../../../theme/ts.dart';
import '../../focus/focus.dart';
import '../../habits/habits.dart';
import '../providers/review_presentation.dart';
import 'review_labels.dart';

class DayDetailSheet extends ConsumerStatefulWidget {
  const DayDetailSheet({
    super.key,
    required this.initial,
    required this.first,
    required this.last,
  });
  final String initial;
  final DateTime first, last;

  @override
  ConsumerState<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends ConsumerState<DayDetailSheet> {
  late final _date = localValueProvider(widget.initial);

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(_date);
    final parsed = dayOnly(DateTime.parse(date));
    final ts = TS.of(context);
    final records =
        ref.watch(focusRecordsProvider).where((r) => r.date == date).toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    final habits = ref
        .watch(habitsProvider)
        .where((h) => h.dates.contains(date))
        .toList();
    final total = records.fold<num>(0, (sum, record) => sum + record.seconds);
    void shift(int delta) {
      final nextDay = parsed.add(Duration(days: delta));
      if (nextDay.isBefore(widget.first) || nextDay.isAfter(widget.last)) {
        return;
      }
      final next = dayId(nextDay);
      ref.read(_date.notifier).set(next);
      final view = ref.read(reviewSelectionProvider);
      ref
          .read(reviewSelectionProvider.notifier)
          .select(view.copyWith(lastViewedDate: next));
    }

    final items = <Widget>[
      Padding(
        padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
        child: Text(
          '${parsed.month}月${parsed.day}日 周${const ['一', '二', '三', '四', '五', '六', '日'][parsed.weekday - 1]}',
          key: const ValueKey('day-detail-date'),
          style: ts.textStyle.subtitle,
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(vertical: ts.spacing.smPlus),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('专注合计', style: ts.textStyle.caption),
                  SizedBox(height: ts.spacing.xs),
                  _DurationText(total, prominent: true),
                ],
              ),
            ),
            SizedBox(width: ts.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('打卡', style: ts.textStyle.caption),
                  SizedBox(height: ts.spacing.xs),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${habits.length}',
                          style: ts.textStyle.numericTitle,
                        ),
                        TextSpan(text: ' 次', style: ts.textStyle.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (records.isEmpty && habits.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: ts.spacing.lg),
          child: Text('这一天没有记录', style: ts.textStyle.content),
        )
      else ...[
        SizedBox(height: ts.spacing.sm),
        Text('专注记录', style: ts.textStyle.captionStrong),
        SizedBox(height: ts.spacing.sm),
        if (records.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
            child: Text('这一天没有专注记录', style: ts.textStyle.caption),
          )
        else ...[
          _RecordColumns(
            time: Text('开始', style: ts.textStyle.micro),
            mode: Text('类型', style: ts.textStyle.micro),
            duration: Text(
              '时长',
              textAlign: TextAlign.right,
              style: ts.textStyle.micro,
            ),
          ),
          for (var i = 0; i < records.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: ts.spacing.smPlus),
              child: _RecordColumns(
                time: Text(
                  records[i].time,
                  key: ValueKey('day-record-time-$i'),
                  style: ts.textStyle.numericContent.copyWith(
                    fontSize: ts.textStyle.caption.fontSize,
                    color: ts.colors.onSurfaceMuted,
                  ),
                ),
                mode: Text(
                  modeLabel(records[i].mode),
                  key: ValueKey('day-record-mode-$i'),
                  style: ts.textStyle.content,
                ),
                duration: Align(
                  alignment: Alignment.centerRight,
                  child: _DurationText(
                    records[i].seconds,
                    key: ValueKey('day-record-duration-$i'),
                  ),
                ),
              ),
            ),
        ],
        SizedBox(height: ts.spacing.md),
        Text('打卡记录', style: ts.textStyle.captionStrong),
        SizedBox(height: ts.spacing.sm),
        if (habits.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: ts.spacing.sm),
            child: Text('这一天没有打卡记录', style: ts.textStyle.caption),
          )
        else
          for (final habit in habits)
            Padding(
              padding: EdgeInsets.symmetric(vertical: ts.spacing.smPlus),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommonIcon(
                    name: CommonIconName.circleCheck,
                    dimension: ts.sizing.iconSm,
                    color: ts.colors.primary,
                  ),
                  SizedBox(width: ts.spacing.sm),
                  Expanded(
                    child: Text(habit.name, style: ts.textStyle.content),
                  ),
                ],
              ),
            ),
      ],
    ];

    Widget navigation(bool previous) {
      final enabled = previous
          ? parsed.isAfter(widget.first)
          : parsed.isBefore(widget.last);
      return CommonPressableSurface(
        key: ValueKey(previous ? 'day-previous' : 'day-next'),
        onPressed: enabled ? () => shift(previous ? -1 : 1) : null,
        child: Opacity(
          opacity: enabled ? ts.opacity.visible : ts.opacity.disabled,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: ts.sizing.touch),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: ts.spacing.smPlus),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (previous)
                    CommonIcon(
                      name: CommonIconName.chevronLeft,
                      dimension: ts.sizing.iconSm,
                    ),
                  if (previous) SizedBox(width: ts.spacing.xs),
                  Text(previous ? '前一天' : '后一天', style: ts.textStyle.label),
                  if (!previous) SizedBox(width: ts.spacing.xs),
                  if (!previous)
                    CommonIcon(
                      name: CommonIconName.chevronRight,
                      dimension: ts.sizing.iconSm,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: CommonDataList(
            key: ValueKey(date),
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            divided: false,
            surface: CommonDataListSurface.none,
            rounded: CommonDataListRounded.none,
            itemCount: items.length,
            itemBuilder: (_, index) => items[index],
          ),
        ),
        SizedBox(height: ts.spacing.smPlus),
        Row(
          children: [
            Expanded(child: navigation(true)),
            SizedBox(width: ts.spacing.smPlus),
            Expanded(child: navigation(false)),
          ],
        ),
      ],
    );
  }
}

class _RecordColumns extends StatelessWidget {
  const _RecordColumns({
    required this.time,
    required this.mode,
    required this.duration,
  });
  final Widget time, mode, duration;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: ts.sizing.controlLg, child: time),
        SizedBox(width: ts.spacing.sm),
        Expanded(child: mode),
        SizedBox(width: ts.spacing.sm),
        Expanded(flex: 2, child: duration),
      ],
    );
  }
}

class _DurationText extends StatelessWidget {
  const _DurationText(this.seconds, {super.key, this.prominent = false});
  final num seconds;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final label = durationLabel(seconds, compact: true);
    final spans = <TextSpan>[];
    final digits = RegExp(r'\d+(?:\.\d+)?');
    var offset = 0;
    for (final match in digits.allMatches(label)) {
      if (offset < match.start) {
        spans.add(
          TextSpan(
            text: label.substring(offset, match.start),
            style: ts.textStyle.caption,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: prominent
              ? ts.textStyle.numericTitle
              : ts.textStyle.numericContent,
        ),
      );
      offset = match.end;
    }
    if (offset < label.length) {
      spans.add(
        TextSpan(text: label.substring(offset), style: ts.textStyle.caption),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: prominent ? TextAlign.left : TextAlign.right,
    );
  }
}
