import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/time.dart';
import '../../../theme/ts.dart';
import '../action/icon.dart';
import '../action/icon_button.dart';
import '../action/pressable_surface.dart';
import 'calendar_dates.dart';

class CommonCalendarDay {
  const CommonCalendarDay({
    required this.date,
    required this.selected,
    required this.today,
    required this.disabled,
  });
  final String date;
  final bool selected;
  final bool today;
  final bool disabled;
}

typedef CommonCalendarDayBuilder =
    Widget Function(BuildContext context, CommonCalendarDay day);

/// Controlled date-only calendar. All chronology is supplied by the caller.
class CommonMonthCalendar extends StatefulWidget {
  const CommonMonthCalendar({
    super.key,
    required this.month,
    this.value,
    this.today,
    this.onChanged,
    this.onMonthChanged,
    this.disabledDates = const {},
    this.dayLabels = const {},
    this.showHeader = true,
    this.customDayAppearance = false,
    this.dayBuilder,
    this.dayShape,
    this.dayInteractionBuilder,
    this.label = '选择日期',
  });
  final Widget Function(BuildContext, CommonCalendarDay, FocusNode, Widget)?
  dayInteractionBuilder;
  final String month;
  final String? value;
  final String? today;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onMonthChanged;
  final Set<String> disabledDates;
  final Map<String, String> dayLabels;
  final bool showHeader;
  final bool customDayAppearance;
  final CommonCalendarDayBuilder? dayBuilder;
  final OutlinedBorder? dayShape;
  final String label;

  @override
  State<CommonMonthCalendar> createState() => _CommonMonthCalendarState();
}

class _CommonMonthCalendarState extends State<CommonMonthCalendar> {
  final Map<String, FocusNode> _nodes = {};
  List<String> _days(DateTime first) => [
    for (
      var day = 1;
      day <= DateUtils.getDaysInMonth(first.year, first.month);
      day++
    )
      calendarDayId(DateTime.utc(first.year, first.month, day)),
  ];
  void _move(String date, int delta, {bool edge = false}) {
    final first = parseCalendarMonth(widget.month);
    if (first == null) return;
    final available = _days(
      first,
    ).where((date) => !widget.disabledDates.contains(date)).toList();
    if (available.isEmpty) return;
    if (edge) {
      _nodes[delta < 0 ? available.first : available.last]?.requestFocus();
      return;
    }
    var candidate = parseCalendarDay(date)!.add(Duration(days: delta));
    for (
      var i = 0;
      i < 31 && candidate.month == first.month && candidate.year == first.year;
      i++
    ) {
      final id = calendarDayId(candidate);
      if (!widget.disabledDates.contains(id)) {
        _nodes[id]?.requestFocus();
        return;
      }
      candidate = candidate.add(Duration(days: delta < 0 ? -1 : 1));
    }
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = parseCalendarMonth(widget.month);
    if (first == null) return const SizedBox.shrink();
    final ts = TS.of(context);
    final days = _days(first);
    for (final date
        in _nodes.keys.where((date) => !days.contains(date)).toList()) {
      _nodes.remove(date)!.dispose();
    }
    final available = days
        .where((date) => !widget.disabledDates.contains(date))
        .toList();
    final focusDate = available.contains(widget.value)
        ? widget.value
        : available.firstOrNull;
    for (final date in days) {
      _nodes.putIfAbsent(date, () => FocusNode()).skipTraversal =
          date != focusDate ||
          (widget.onChanged == null && widget.dayInteractionBuilder == null);
    }
    final offset = first.weekday - DateTime.monday;
    final count = ((offset + days.length) / 7).ceil() * 7;
    return Semantics(
      label: widget.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showHeader) ...[
            Row(
              children: [
                CommonIconButton(
                  name: CommonIconName.chevronLeft,
                  label: '上个月',
                  variant: CommonIconButtonVariant.text,
                  onPressed: widget.onMonthChanged == null
                      ? null
                      : () => widget.onMonthChanged!(
                          shiftCalendarMonth(widget.month, -1),
                        ),
                ),
                Expanded(
                  child: Text(
                    '${first.year}年${first.month}月',
                    textAlign: TextAlign.center,
                    style: ts.textStyle.subtitle,
                  ),
                ),
                CommonIconButton(
                  name: CommonIconName.chevronRight,
                  label: '下个月',
                  variant: CommonIconButtonVariant.text,
                  onPressed: widget.onMonthChanged == null
                      ? null
                      : () => widget.onMonthChanged!(
                          shiftCalendarMonth(widget.month, 1),
                        ),
                ),
              ],
            ),
            Divider(color: ts.colors.divider, height: ts.spacing.sm),
          ],
          Row(
            children: [
              for (final day in weekdayLabels)
                Expanded(
                  child: SizedBox(
                    height: ts.sizing.controlSm,
                    child: Center(
                      child: Text(day, style: ts.textStyle.caption),
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < count ~/ 7; row++)
            Padding(
              padding: EdgeInsets.only(
                top: widget.customDayAppearance
                    ? ts.spacing.xxs
                    : ts.spacing.smPlus,
              ),
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child:
                          row * 7 + column < offset ||
                              row * 7 + column - offset >= days.length
                          ? SizedBox(height: ts.sizing.touch)
                          : _day(context, days[row * 7 + column - offset]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, String date) {
    final ts = TS.of(context);
    final disabled =
        widget.disabledDates.contains(date) ||
        (widget.onChanged == null && widget.dayInteractionBuilder == null);
    final state = CommonCalendarDay(
      date: date,
      selected: date == widget.value,
      today: date == widget.today,
      disabled: disabled,
    );
    final child =
        widget.dayBuilder?.call(context, state) ??
        Center(
          child: Text(
            '${int.parse(date.substring(8))}',
            style: ts.textStyle.numericContent.copyWith(
              color: state.selected && !widget.customDayAppearance
                  ? ts.colors.onPrimary
                  : ts.colors.onSurface,
            ),
          ),
        );
    final node = _nodes[date]!;
    final visual = ConstrainedBox(
      constraints: BoxConstraints(minHeight: ts.sizing.touch),
      child: widget.customDayAppearance
          ? child
          : Padding(
              padding: EdgeInsets.all(ts.spacing.xs),
              child: CustomPaint(
                painter: _CalendarDayPainter(
                  selected: state.selected,
                  today: state.today,
                  fill: ts.colors.primary,
                  stroke: ts.border.widthHairline,
                ),
                child: SizedBox(height: ts.sizing.controlMd, child: child),
              ),
            ),
    );
    final action =
        widget.dayInteractionBuilder?.call(context, state, node, visual) ??
        CommonPressableSurface(
          focusNode: node,
          onPressed: disabled ? null : () => widget.onChanged!(date),
          shape:
              widget.dayShape ??
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ts.radius.full),
              ),
          child: visual,
        );
    return Semantics(
      label: widget.dayLabels[date] ?? date,
      selected: widget.value == null ? null : state.selected,
      enabled: !disabled,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _move(date, -1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _move(date, 1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _move(date, -7),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _move(date, 7),
          const SingleActivator(LogicalKeyboardKey.home): () =>
              _move(date, -1, edge: true),
          const SingleActivator(LogicalKeyboardKey.end): () =>
              _move(date, 1, edge: true),
        },
        child: Opacity(
          opacity: disabled ? ts.opacity.disabled : ts.opacity.visible,
          child: action,
        ),
      ),
    );
  }
}

class _CalendarDayPainter extends CustomPainter {
  const _CalendarDayPainter({
    required this.selected,
    required this.today,
    required this.fill,
    required this.stroke,
  });
  final bool selected;
  final bool today;
  final Color fill;
  final double stroke;
  @override
  void paint(Canvas canvas, Size size) {
    if (!selected && !today) return;
    final paint = Paint()
      ..isAntiAlias = true
      ..color = fill
      ..strokeWidth = stroke
      ..style = selected ? PaintingStyle.fill : PaintingStyle.stroke;
    canvas.drawCircle(
      size.center(Offset.zero),
      (size.shortestSide - stroke) / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CalendarDayPainter oldDelegate) =>
      selected != oldDelegate.selected ||
      today != oldDelegate.today ||
      fill != oldDelegate.fill ||
      stroke != oldDelegate.stroke;
}
