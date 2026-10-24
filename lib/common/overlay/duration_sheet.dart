import '../motion/content_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/local_value.dart';
import '../overlay/app_pop.dart';
import '../widgets.dart';
import '../../theme/ts.dart';

Future<int?> pickYikeDuration({
  required String title,
  required int initial,
  int minimum = 1,
  int maximum = 86399,
  bool seconds = true,
  bool hours = true,
  bool secondsOnly = false,
  String confirm = '确认',
  bool autoSave = false,
  bool Function(int)? onConfirm,
}) {
  final sheet = AppSheet<int>();
  return sheet.show(
    title: title,
    material: CommonSurfaceMaterial.glass,
    child: DurationSheetBody(
      initial: initial,
      minimum: minimum,
      maximum: maximum,
      seconds: seconds,
      hours: hours,
      secondsOnly: secondsOnly,
      confirm: confirm,
      autoSave: autoSave,
      onSave: (value) {
        if (!(onConfirm?.call(value) ?? true)) return false;
        if (!autoSave) sheet.complete(value);
        return true;
      },
    ),
  );
}

class DurationSheetBody extends ConsumerStatefulWidget {
  const DurationSheetBody({
    super.key,
    required this.initial,
    required this.onSave,
    this.minimum = 1,
    this.maximum = 86399,
    this.seconds = true,
    this.hours = true,
    this.secondsOnly = false,
    this.confirm = '确认',
    this.autoSave = false,
  });
  final int initial, minimum, maximum;
  final bool seconds, autoSave, hours, secondsOnly;
  final String confirm;
  final bool Function(int) onSave;
  @override
  ConsumerState<DurationSheetBody> createState() => _DurationSheetBodyState();
}

class _DurationSheetBodyState extends ConsumerState<DurationSheetBody> {
  late final _value = localValueProvider(widget.initial);
  final _attempted = localValueProvider(false);
  final _saveFailed = localValueProvider(false);
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(_value);
    final invalid = value < widget.minimum || value > widget.maximum;
    final ts = TS.of(context);
    return AppSheetContent(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DurationWheels(
            value: value,
            seconds: widget.seconds,
            hours: widget.hours,
            secondsOnly: widget.secondsOnly,
            minimum: widget.minimum,
            maximum: widget.maximum,
            filled: widget.autoSave,
            onSettled: widget.autoSave
                ? (value) {
                    ref
                        .read(_attempted.notifier)
                        .set(value < widget.minimum || value > widget.maximum);
                    if (value < widget.minimum || value > widget.maximum) {
                      return;
                    }
                    ref.read(_saveFailed.notifier).set(!widget.onSave(value));
                  }
                : null,
            maxHour: widget.maximum ~/ 3600,
            onChanged: (value) {
              ref.read(_value.notifier).set(value);
              ref.read(_attempted.notifier).set(false);
              ref.read(_saveFailed.notifier).set(false);
            },
          ),
          MotionExpand(
            expanded: invalid && ref.watch(_attempted),
            child: Text(
              '请选择有效时长（${widget.minimum}–${widget.maximum} 秒）',
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
          ),
          MotionExpand(
            expanded: ref.watch(_saveFailed),
            child: Text(
              '尚未保存，请重试；关闭后可能丢失',
              style: ts.textStyle.caption.copyWith(color: ts.colors.error),
            ),
          ),
        ],
      ),
      actions: widget.autoSave
          ? null
          : CommonButton(
              label: widget.confirm,
              kind: CommonButtonKind.accent,
              size: CommonControlSize.lg,
              block: true,
              shape: CommonButtonShape.pill,
              onPressed: () {
                if (invalid) {
                  ref.read(_attempted.notifier).set(true);
                  return;
                }
                if (!widget.onSave(value)) {
                  ref.read(_saveFailed.notifier).set(true);
                }
              },
            ),
    );
  }
}

class DurationWheels extends StatelessWidget {
  const DurationWheels({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSettled,
    this.filled = false,
    this.seconds = true,
    this.hours = true,
    this.secondsOnly = false,
    this.minimum = 1,
    this.maximum = 86399,
    this.maxHour = 23,
  });
  final int value, maxHour, minimum, maximum;
  final bool seconds, hours, secondsOnly, filled;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onSettled;

  @override
  Widget build(BuildContext context) {
    final bounded = value.clamp(minimum, maximum);
    final hour = hours && !secondsOnly ? bounded ~/ 3600 : 0;
    final minute = secondsOnly ? 0 : bounded ~/ 60 % 60;
    CommonWheelColumn column(
      String id,
      String label,
      String unit,
      int min,
      int max,
    ) => CommonWheelColumn(
      id: id,
      label: label,
      unit: unit,
      numeric: true,
      options: [
        for (var i = min; i <= max; i++)
          CommonWheelOption(value: i, label: i.toString().padLeft(2, '0')),
      ],
    );
    final columns = <CommonWheelColumn>[
      if (hours && !secondsOnly)
        column('hour', '小时', '时', 0, maxHour.clamp(0, maximum ~/ 3600)),
      if (!secondsOnly)
        column(
          'minute',
          '分钟',
          '分',
          0,
          hour == maximum ~/ 3600 ? maximum ~/ 60 % 60 : 59,
        ),
      if (seconds || secondsOnly)
        column(
          'second',
          '秒',
          '秒',
          hour == 0 && minute == 0 ? minimum.clamp(1, 59) : 0,
          secondsOnly
              ? maximum
              : (hour * 3600 + minute * 60 == maximum ~/ 60 * 60
                    ? maximum % 60
                    : 59),
        ),
    ];
    int duration(List<Object> values) {
      var total = 0;
      for (var i = 0; i < columns.length; i++) {
        total +=
            (values[i] as int) *
            switch (columns[i].id) {
              'hour' => 3600,
              'minute' => 60,
              _ => 1,
            };
      }
      return total.clamp(minimum, maximum);
    }

    return CommonWheelPicker(
      visibleRows: 3,
      filled: filled,
      columns: columns,
      values: [
        if (hours && !secondsOnly) hour,
        if (!secondsOnly) minute,
        if (seconds || secondsOnly) secondsOnly ? bounded : bounded % 60,
      ],
      onChanged: (values) => onChanged(duration(values)),
      onSettled: onSettled == null
          ? null
          : (values) => onSettled!(duration(values)),
    );
  }
}
