import 'package:flutter/material.dart';
import '../../theme/ts.dart';

/// Grow on a new period, interpolate a user filter, apply live data directly.
class ChartValue extends StatefulWidget {
  const ChartValue({
    super.key,
    required this.value,
    required this.period,
    required this.filter,
    required this.builder,
  });
  final double value;
  final Object period;
  final Object? filter;
  final Widget Function(BuildContext, double) builder;
  @override
  State<ChartValue> createState() => _ChartValueState();
}

class _ChartValueState extends State<ChartValue>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  late double _from = 0, _to = widget.value;
  bool _initialized = false;
  double get _value => _from + (_to - _from) * _controller.value;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _animate(0, widget.value);
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  void _animate(double from, double to) {
    _from = from;
    _to = to;
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : TS.of(context).motion.durationNormal;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(ChartValue old) {
    super.didUpdateWidget(old);
    if (widget.period != old.period) {
      _animate(0, widget.value);
    } else if (widget.filter != old.filter) {
      _animate(_value, widget.value);
    } else if (widget.value != old.value) {
      _from = _to = widget.value;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _value),
  );
}
