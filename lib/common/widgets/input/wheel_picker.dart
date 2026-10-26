import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/ts.dart';

class CommonWheelOption {
  const CommonWheelOption({required this.value, required this.label});
  final Object value;
  final String label;
}

class CommonWheelColumn {
  const CommonWheelColumn({
    required this.id,
    required this.label,
    required this.options,
    this.unit,
    this.numeric = false,
  });
  final String id;
  final String label;
  final List<CommonWheelOption> options;
  final String? unit;
  final bool numeric;
}

/// One to three controlled, independent native wheels. No duration arithmetic.
class CommonWheelPicker extends StatefulWidget {
  const CommonWheelPicker({
    super.key,
    required this.columns,
    required this.values,
    required this.onChanged,
    this.onSettled,
    this.filled = false,
    this.label,
    this.visibleRows = 5,
    this.disabled = false,
  }) : assert(visibleRows > 0 && visibleRows <= 5 && visibleRows % 2 == 1);
  final List<CommonWheelColumn> columns;
  final List<Object> values;
  final ValueChanged<List<Object>>? onChanged;
  final ValueChanged<List<Object>>? onSettled;
  final String? label;
  final int visibleRows;
  final bool filled;
  final bool disabled;

  @override
  State<CommonWheelPicker> createState() => _CommonWheelPickerState();
}

class _CommonWheelPickerState extends State<CommonWheelPicker> {
  final Map<String, FixedExtentScrollController> _controllers = {};
  final Set<String> _scrolling = {};
  bool _dirty = false, _settleScheduled = false;
  bool get _enabled => !widget.disabled && widget.onChanged != null;

  int _index(int column) {
    final options = widget.columns[column].options;
    final value = column < widget.values.length ? widget.values[column] : null;
    final index = options.indexWhere((option) => option.value == value);
    return index < 0 ? 0 : index;
  }

  void _changed(int column, int index) {
    if (!_enabled) return;
    final values = [
      for (var i = 0; i < widget.columns.length; i++)
        widget
            .columns[i]
            .options[_controllers[widget.columns[i].id]?.hasClients == true
                ? _controllers[widget.columns[i].id]!.selectedItem.clamp(
                    0,
                    widget.columns[i].options.length - 1,
                  )
                : _index(i)]
            .value,
    ];
    final next = widget.columns[column].options[index].value;
    if (column < widget.values.length && widget.values[column] == next) return;
    values[column] = next;
    _dirty = true;
    widget.onChanged!(List.unmodifiable(values));
    _scheduleSettled();
  }

  void _scheduleSettled() {
    if (_settleScheduled) return;
    _settleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleScheduled = false;
      if (!mounted || !_enabled || !_dirty || _scrolling.isNotEmpty) return;
      _dirty = false;
      widget.onSettled?.call(
        List.unmodifiable([
          for (var i = 0; i < widget.columns.length; i++)
            widget
                .columns[i]
                .options[_controllers[widget.columns[i].id]!.hasClients
                    ? _controllers[widget.columns[i].id]!.selectedItem.clamp(
                        0,
                        widget.columns[i].options.length - 1,
                      )
                    : _index(i)]
                .value,
        ]),
      );
    });
  }

  void _move(int column, int index) {
    if (!_enabled) return;
    final options = widget.columns[column].options;
    final bounded = index.clamp(0, options.length - 1);
    _controllers[widget.columns[column].id]!.animateToItem(
      bounded,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : TS.of(context).motion.durationFast,
      curve: TS.of(context).motion.easingStandard,
    );
  }

  @override
  void didUpdateWidget(covariant CommonWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.columns.map((column) => column.id).toSet();
    _scrolling.removeWhere((id) => !ids.contains(id));
    for (final id
        in _controllers.keys.where((id) => !ids.contains(id)).toList()) {
      _controllers.remove(id)!.dispose();
    }
    for (var i = 0; i < widget.columns.length; i++) {
      final controller = _controllers[widget.columns[i].id];
      if (controller != null &&
          controller.hasClients &&
          controller.selectedItem != _index(i)) {
        controller.jumpToItem(_index(i));
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.columns.isEmpty ||
        widget.columns.length > 3 ||
        widget.columns.map((column) => column.id).toSet().length !=
            widget.columns.length ||
        widget.columns.any(
          (column) =>
              column.id.isEmpty ||
              column.options.isEmpty ||
              column.options.map((option) => option.value).toSet().length !=
                  column.options.length,
        )) {
      throw ArgumentError(
        'Provide one to three uniquely identified columns with nonempty, unique options.',
      );
    }
    final ts = TS.of(context);
    final rowHeight = ts.sizing.controlMd;
    return Semantics(
      label: widget.label,
      child: Opacity(
        opacity: widget.disabled ? ts.opacity.disabled : ts.opacity.visible,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.visibleRows == 3 && !widget.filled
                ? Colors.transparent
                : ts.colors.surface,
            borderRadius: BorderRadius.circular(ts.radius.lg),
          ),
          child: SizedBox(
            height: rowHeight * widget.visibleRows,
            child: Row(
              children: [
                for (var column = 0; column < widget.columns.length; column++)
                  Expanded(child: _column(context, column, rowHeight)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _column(BuildContext context, int index, double rowHeight) {
    final ts = TS.of(context);
    final column = widget.columns[index];
    final controller = _controllers.putIfAbsent(
      column.id,
      () => FixedExtentScrollController(initialItem: _index(index)),
    );
    final selected = _index(index);
    return Semantics(
      key: ValueKey('wheel-column-${column.id}'),
      label: column.label,
      value: column.options[selected].label,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _move(index, controller.selectedItem - 1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _move(index, controller.selectedItem + 1),
          const SingleActivator(LogicalKeyboardKey.home): () => _move(index, 0),
          const SingleActivator(LogicalKeyboardKey.end): () =>
              _move(index, column.options.length - 1),
        },
        child: Focus(
          canRequestFocus: _enabled,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Padding(
                  padding: EdgeInsets.all(ts.spacing.xs),
                  child: Container(
                    height: rowHeight,
                    decoration: BoxDecoration(
                      color: widget.visibleRows == 3 && !widget.filled
                          ? ts.colors.surface
                          : ts.colors.surfaceRecessed,
                      borderRadius: BorderRadius.circular(ts.radius.sm),
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final selectedStyle = column.numeric
                      ? ts.textStyle.numericTitle
                      : ts.textStyle.subtitle;
                  final otherStyle = column.numeric
                      ? ts.textStyle.numericContent
                      : ts.textStyle.content;
                  Size measure(String text, TextStyle style) {
                    final painter = TextPainter(
                      text: TextSpan(text: text, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final size = painter.size;
                    painter.dispose();
                    return size;
                  }

                  var numberWidth = 0.0, numberHeight = 0.0;
                  for (final option in column.options) {
                    for (final style in [selectedStyle, otherStyle]) {
                      final size = measure(option.label, style);
                      numberWidth = math.max(numberWidth, size.width);
                      numberHeight = math.max(numberHeight, size.height);
                    }
                  }
                  final unitSize = measure(
                    column.unit ?? '',
                    ts.textStyle.caption,
                  );
                  final unitGap = column.unit == null ? 0.0 : ts.spacing.xs;
                  final scale = math.min(
                    1.0,
                    math.min(
                      math.max(0.0, constraints.maxWidth - unitGap * 2) /
                          math.max(1, numberWidth + unitSize.width * 2),
                      (rowHeight - ts.spacing.xs) / math.max(1, numberHeight),
                    ),
                  );
                  TextStyle scaled(TextStyle style) => style.copyWith(
                    fontSize: style.fontSize! * scale,
                    letterSpacing: style.letterSpacing == null
                        ? null
                        : style.letterSpacing! * scale,
                  );
                  final unitWidth = unitSize.width * scale;
                  final unitHeight = unitSize.height * scale;
                  final fittedNumberWidth = numberWidth * scale;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.depth != 0) return false;
                          if (notification is ScrollStartNotification) {
                            _scrolling.add(column.id);
                          }
                          if (notification is ScrollEndNotification) {
                            _scrolling.remove(column.id);
                            _scheduleSettled();
                          }
                          return false;
                        },
                        child: ListWheelScrollView.useDelegate(
                          controller: controller,
                          itemExtent: rowHeight,
                          physics: _enabled
                              ? const FixedExtentScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          onSelectedItemChanged: (item) =>
                              _changed(index, item),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: column.options.length,
                            builder: (context, item) => GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _enabled ? () => _move(index, item) : null,
                              child: Center(
                                child: SizedBox(
                                  width: fittedNumberWidth,
                                  child: Text(
                                    column.options[item].label,
                                    key: item == selected
                                        ? ValueKey('wheel-number-${column.id}')
                                        : null,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: scaled(
                                      item == selected
                                          ? selectedStyle
                                          : otherStyle.copyWith(
                                              color: ts.colors.onSurfaceMuted,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (column.unit != null)
                        Positioned(
                          left:
                              (constraints.maxWidth + fittedNumberWidth) / 2 +
                              unitGap,
                          top:
                              (rowHeight * widget.visibleRows - unitHeight) /
                                  2 +
                              ts.spacing.xs,
                          width: unitWidth,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  column.unit!,
                                  key: ValueKey('wheel-unit-${column.id}'),
                                  style: scaled(ts.textStyle.caption),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
