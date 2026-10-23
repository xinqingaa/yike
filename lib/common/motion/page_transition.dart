import 'package:flutter/material.dart';

import '../../theme/ts.dart';
import 'content_transition.dart';

/// A clipped page turn. Only the latest page receives input and semantics.
class MotionPage<T> extends StatefulWidget {
  const MotionPage({
    super.key,
    required this.value,
    required this.direction,
    required this.child,
    this.resize = true,
  });
  final T value;
  final double Function(T before, T after) direction;
  final Widget child;
  final bool resize;

  @override
  State<MotionPage<T>> createState() => _MotionPageState<T>();
}

class _MotionPageState<T> extends State<MotionPage<T>>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this, value: 1);
  GlobalKey _currentKey = GlobalKey();
  GlobalKey? _previousKey;
  Widget? _previous;
  T? _previousValue;
  double _incomingStart = 0, _outgoingStart = 0, _direction = 1;
  bool _enabled = false;

  double get _phase =>
      TS.of(context).motion.easingStandard.transform(_motion.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = motionEnabled(context);
    if (!_enabled) _motion.value = 1;
  }

  @override
  void didUpdateWidget(covariant MotionPage<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final phase = _phase;
    final reversing = !_motion.isCompleted && widget.value == _previousValue;
    final nextStart = reversing
        ? _outgoingStart + (-_direction - _outgoingStart) * phase
        : widget.direction(oldWidget.value, widget.value).sign;
    final nextKey = reversing ? _previousKey! : GlobalKey();
    _outgoingStart = _incomingStart * (1 - phase);
    _incomingStart = reversing ? nextStart : (nextStart == 0 ? 1 : nextStart);
    _direction = widget.direction(oldWidget.value, widget.value).sign;
    if (_direction == 0) _direction = 1;
    _previous = oldWidget.child;
    _previousValue = oldWidget.value;
    _previousKey = _currentKey;
    _currentKey = nextKey;
    _motion.duration = TS.of(context).motion.durationNormal;
    if (_enabled) {
      _motion.forward(from: 0);
    } else {
      _motion.value = 1;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ClipRect(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final phase = _phase;
          return Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.topCenter,
            children: [
              if (!_motion.isCompleted && _previous != null)
                FractionalTranslation(
                  translation: Offset(
                    _outgoingStart + (-_direction - _outgoingStart) * phase,
                    0,
                  ),
                  child: IgnorePointer(
                    child: ExcludeFocus(
                      child: ExcludeSemantics(
                        child: KeyedSubtree(
                          key: _previousKey,
                          child: _previous!,
                        ),
                      ),
                    ),
                  ),
                ),
              FractionalTranslation(
                translation: Offset(_incomingStart * (1 - phase), 0),
                child: KeyedSubtree(key: _currentKey, child: widget.child),
              ),
            ],
          );
        },
      ),
    );
    return widget.resize ? MotionSize(child: content) : content;
  }
}
