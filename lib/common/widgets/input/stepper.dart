import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/icon.dart';

/// Controlled numeric input. Keyboard submission and buttons share normalization.
class CommonStepper extends StatefulWidget {
  const CommonStepper({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.min = 0,
    this.max = 10,
    this.step = 1,
    this.disabled = false,
  });
  final double value;
  final ValueChanged<double>? onChanged;
  final String? label;
  final double min;
  final double max;
  final double step;
  final bool disabled;

  @override
  State<CommonStepper> createState() => _CommonStepperState();
}

class _CommonStepperState extends State<CommonStepper> {
  late final TextEditingController _controller;
  double get _min => widget.min.isFinite ? widget.min : 0;
  double get _max =>
      widget.max.isFinite && widget.max >= _min ? widget.max : _min;
  double get _step => widget.step.isFinite && widget.step > 0 ? widget.step : 1;
  bool get _enabled => !widget.disabled && widget.onChanged != null;

  double _normalize(double value) {
    final bounded = (value.isFinite ? value : _min).clamp(_min, _max);
    final aligned = _min + ((bounded - _min) / _step).round() * _step;
    return double.parse(aligned.clamp(_min, _max).toStringAsFixed(8));
  }

  String _text(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _text(_normalize(widget.value)));
  }

  @override
  void didUpdateWidget(covariant CommonStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _text(_normalize(widget.value));
    if (_controller.text != next) _controller.text = next;
  }

  void _commit(double? value) {
    if (!_enabled) return;
    if (value != null && value.isFinite) widget.onChanged!(_normalize(value));
    _controller.text = _text(_normalize(widget.value));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final current = _normalize(widget.value);
    return Semantics(
      label: widget.label,
      child: Opacity(
        opacity: widget.disabled ? ts.opacity.disabled : ts.opacity.visible,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.label != null) ...[
              Text(widget.label!, style: ts.textStyle.caption),
              SizedBox(height: ts.spacing.sm),
            ],
            DecoratedBox(
              decoration: BoxDecoration(
                color: ts.colors.surfaceRecessed,
                borderRadius: BorderRadius.circular(ts.radius.md),
                border: Border.fromBorderSide(ts.border.hairline),
              ),
              child: Padding(
                padding: EdgeInsets.all(ts.spacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '减少',
                      onPressed: _enabled && current > _min
                          ? () => _commit(current - _step)
                          : null,
                      constraints: BoxConstraints(
                        minWidth: ts.sizing.touch,
                        minHeight: ts.sizing.touch,
                      ),
                      icon: Text('−', style: ts.textStyle.numericTitle),
                    ),
                    SizedBox(
                      width: ts.sizing.avatarLg,
                      child: TextField(
                        controller: _controller,
                        enabled: _enabled,
                        textAlign: TextAlign.center,
                        style: ts.textStyle.numericTitle,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onSubmitted: (text) => _commit(double.tryParse(text)),
                        onTapOutside: (_) {
                          _commit(double.tryParse(_controller.text));
                          FocusScope.of(context).unfocus();
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '增加',
                      onPressed: _enabled && current < _max
                          ? () => _commit(current + _step)
                          : null,
                      constraints: BoxConstraints(
                        minWidth: ts.sizing.touch,
                        minHeight: ts.sizing.touch,
                      ),
                      icon: const CommonIcon(name: CommonIconName.plus),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
