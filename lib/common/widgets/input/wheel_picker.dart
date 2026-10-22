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
    this.label,
    this.disabled = false,
  });
  final List<CommonWheelColumn> columns;
  final List<Object> values;
  final ValueChanged<List<Object>>? onChanged;
  final String? label;
  final bool disabled;

  @override
  State<CommonWheelPicker> createState() => _CommonWheelPickerState();
}

class _CommonWheelPickerState extends State<CommonWheelPicker> {
  final Map<String, FixedExtentScrollController> _controllers = {};
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
        widget.columns[i].options[_index(i)].value,
    ];
    final next = widget.columns[column].options[index].value;
    if (values[column] == next) return;
    values[column] = next;
    widget.onChanged!(List.unmodifiable(values));
  }

  void _move(int column, int index) {
    if (!_enabled) return;
    final options = widget.columns[column].options;
    final bounded = index.clamp(0, options.length - 1);
    _controllers[widget.columns[column].id]!.animateToItem(
      bounded,
      duration: TS.of(context).motion.durationFast,
      curve: TS.of(context).motion.easingStandard,
    );
  }

  @override
  void didUpdateWidget(covariant CommonWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.columns.map((column) => column.id).toSet();
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
            color: ts.colors.surface,
            borderRadius: BorderRadius.circular(ts.radius.lg),
          ),
          child: SizedBox(
            height: rowHeight * 5,
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
                      color: ts.colors.surfaceRecessed,
                      borderRadius: BorderRadius.circular(ts.radius.sm),
                    ),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: rowHeight,
                physics: _enabled
                    ? const FixedExtentScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onSelectedItemChanged: (item) => _changed(index, item),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: column.options.length,
                  builder: (context, item) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _enabled ? () => _move(index, item) : null,
                    child: Center(
                      child: Text(
                        column.options[item].label,
                        style: item == selected
                            ? (column.numeric
                                  ? ts.textStyle.numericTitle
                                  : ts.textStyle.subtitle)
                            : ts.textStyle.content.copyWith(
                                color: ts.colors.onSurfaceMuted,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              if (column.unit != null)
                Positioned(
                  right: ts.spacing.xs,
                  child: IgnorePointer(
                    child: Text(column.unit!, style: ts.textStyle.caption),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
