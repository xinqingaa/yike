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
    this.confirm = '确认',
    this.autoSave = false,
  });
  final int initial, minimum, maximum;
  final bool seconds, autoSave;
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
              '请选择 ${widget.minimum == 1 ? '至少 1 秒' : '有效时长'}，不超过 ${widget.maximum ~/ 60} 分钟',
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
    this.maxHour = 23,
  });
  final int value, maxHour;
  final bool seconds;
  final bool filled;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onSettled;
  @override
  Widget build(BuildContext context) {
    CommonWheelColumn column(String id, String label, String unit, int max) =>
        CommonWheelColumn(
          id: id,
          label: label,
          unit: unit,
          numeric: true,
          options: [
            for (var i = 0; i <= max; i++)
              CommonWheelOption(value: i, label: i.toString().padLeft(2, '0')),
          ],
        );
    int duration(List<Object> values) =>
        (values[0] as int) * 3600 +
        (values[1] as int) * 60 +
        (seconds ? values[2] as int : 0);
    return CommonWheelPicker(
      visibleRows: 3,
      filled: filled,
      columns: [
        column('hour', '小时', '时', maxHour),
        column('minute', '分钟', '分', 59),
        if (seconds) column('second', '秒', '秒', 59),
      ],
      values: [value ~/ 3600, value ~/ 60 % 60, if (seconds) value % 60],
      onChanged: (values) => onChanged(duration(values)),
      onSettled: onSettled == null
          ? null
          : (values) => onSettled!(duration(values)),
    );
  }
}
