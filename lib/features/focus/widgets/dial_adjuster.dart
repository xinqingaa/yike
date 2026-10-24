import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/feedback/feedback_cue.dart';
import '../../../common/feedback/feedback_service.dart';
import '../../../common/motion/motion_activity.dart';
import '../../../common/time.dart';
import '../../../theme/ts.dart';
import '../logic/dial_adjustment.dart';
import '../models/focus_view.dart';

/// Page-owned coordination: flush before navigation or a different business input.
class DialAdjustmentController extends ValueNotifier<bool> {
  DialAdjustmentController() : super(false);
  VoidCallback? _finish;
  void finish() => _finish?.call();
}

class _ImmediateDialRecognizer extends OneSequenceGestureRecognizer {
  ValueChanged<PointerEvent>? onEvent;
  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onEvent?.call(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    onEvent?.call(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
  @override
  String get debugDescription => 'dial adjustment';
}

class DialAdjuster extends ConsumerStatefulWidget {
  const DialAdjuster({
    super.key,
    required this.mode,
    required this.seconds,
    required this.maximum,
    required this.scale,
    required this.enabled,
    required this.controller,
    required this.onCommit,
    required this.builder,
  });
  final TimerMode mode;
  final int seconds, maximum, scale;
  final bool enabled;
  final DialAdjustmentController controller;
  final bool Function(int seconds, int expectedValue, int expectedMaximum)
  onCommit;
  final Widget Function(double? draft) builder;
  @override
  ConsumerState<DialAdjuster> createState() => _DialAdjusterState();
}

class _DialAdjusterState extends ConsumerState<DialAdjuster>
    with SingleTickerProviderStateMixin, RouteAware {
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;
  final _draft = ValueNotifier<double?>(null);
  final _feedbackClock = Stopwatch()..start();
  ModalRoute<dynamic>? _route;
  int? _pointer;
  Offset? _point, _down;
  Size _size = Size.zero;
  VelocityTracker? _velocity;
  double _raw = 0, _previousFeedback = 0, _phaseStart = 0, _lastTick = 0;
  int _base = 0, _outside = 0, _lastFeedback = -1000;
  int? _pendingValue;
  bool _moved = false, _active = true, _reduced = false, _settling = false;
  Simulation? _simulation;
  int _target = 1;

  bool get _busy => _draft.value != null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) _finish();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (_route != next) {
      if (_route != null) motionRouteObserver.unsubscribe(this);
      _route = next;
      if (next != null) motionRouteObserver.subscribe(this, next);
    }
    _active = MotionGate.activeOf(context);
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_busy && (!_active || _reduced)) {
      // Visibility may change during build. Commit at the next safe boundary;
      // the command validates the old value and range before accepting it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
    }
  }

  @override
  void didPushNext() => _finish();

  @override
  void didUpdateWidget(covariant DialAdjuster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds == _pendingValue) _pendingValue = null;
    if (_busy &&
        (!widget.enabled ||
            widget.mode != oldWidget.mode ||
            widget.maximum != oldWidget.maximum ||
            widget.scale != oldWidget.scale)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
    }
  }

  void _cue(FeedbackCue cue) {
    if (!MotionGate.activeNowOf(context)) return;
    final now = _feedbackClock.elapsedMilliseconds;
    if (now - _lastFeedback < 40) return;
    _lastFeedback = now;
    ref
        .read(feedbackServiceProvider)
        .play(cue, theme: TS.of(context).pack.id, scope: widget.mode.name);
  }

  void _show(double raw) {
    _raw = raw;
    final outside = raw < 1
        ? -1
        : raw > widget.maximum
        ? 1
        : 0;
    final valid = raw.clamp(1, widget.maximum).toDouble();
    if (outside != 0 && outside != _outside) {
      _cue(FeedbackCue.dialLimit);
    } else if (valid.floor() != _previousFeedback.floor()) {
      _cue(
        DialAdjustment.crossedMinute(_previousFeedback, valid)
            ? FeedbackCue.dialMinute
            : FeedbackCue.dialSecond,
      );
    }
    _outside = outside;
    _previousFeedback = valid;
    _draft.value = DialAdjustment.damp(raw, widget.maximum, widget.scale);
  }

  void _event(PointerEvent event) {
    if (!widget.enabled || !_active) return;
    if (event is PointerDownEvent) {
      if (_pointer != null) return;
      _finish();
      _base = _pendingValue ?? widget.seconds;
      _raw = _base.toDouble();
      _previousFeedback = _raw;
      _down = _point = event.localPosition;
      _pointer = event.pointer;
      _moved = false;
      _outside = 0;
      _lastFeedback = -1000;
      _velocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, Offset(_raw / widget.scale, 0));
      _draft.value = _raw;
      widget.controller._finish = _finish;
      widget.controller.value = true;
    } else if (event.pointer == _pointer && event is PointerMoveEvent) {
      final point = event.localPosition;
      final last = _point!;
      _point = point;
      if (!_moved && (point - _down!).distance < 4) return;
      if (!_moved) {
        _moved = true;
      }
      final ts = TS.of(context);
      final water = ts.pack.id.endsWith('water');
      final sundial = ts.pack.id.endsWith('sundial');
      final center = Offset(
        _size.width / 2,
        sundial ? _size.width * 158 / 316 : _size.height / 2,
      );
      final radius = _size.width / 2;
      final currentVector = point - center, lastVector = last - center;
      double turns;
      if (water ||
          currentVector.distance < radius * .2 ||
          lastVector.distance < radius * .2) {
        turns = (last.dy - point.dy) / (water ? _size.height : _size.width);
      } else {
        turns =
            DialAdjustment.angleDelta(
              math.atan2(lastVector.dy, lastVector.dx),
              math.atan2(currentVector.dy, currentVector.dx),
            ) /
            (2 * math.pi);
      }
      _show(_raw + turns * widget.scale);
      _velocity!.addPosition(event.timeStamp, Offset(_raw / widget.scale, 0));
    } else if (event.pointer == _pointer &&
        (event is PointerUpEvent || event is PointerCancelEvent)) {
      _pointer = null;
      if (!_moved || event is PointerCancelEvent || _reduced) {
        _finish();
        return;
      }
      final turns = _velocity!.getVelocity().pixelsPerSecond.dx.clamp(
        -2.0,
        2.0,
      );
      final speed = turns * widget.scale;
      _phaseStart = _lastTick = 0;
      _settling = false;
      if (turns.abs() > .1 && _raw >= 1 && _raw <= widget.maximum) {
        _simulation = FrictionSimulation(.135, _raw, speed);
      } else {
        _spring(speed, slow: turns.abs() <= .05);
      }
      _ticker.start();
    }
  }

  void _spring(double speed, {bool slow = false}) {
    _target = DialAdjustment.snap(_raw, widget.maximum, slow: slow);
    _simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 300, damping: 30),
      _raw,
      _target.toDouble(),
      speed,
      tolerance: Tolerance(
        distance: widget.scale / 3000,
        velocity: widget.scale / 600,
      ),
    );
    _settling = true;
    _phaseStart = _lastTick;
  }

  void _tick(Duration elapsed) {
    _lastTick = elapsed.inMicroseconds / 1000000;
    final t = _lastTick - _phaseStart;
    final simulation = _simulation!;
    _show(simulation.x(t));
    if (_lastTick >= 1.2) {
      _finish(target: _settling ? _target : null);
      return;
    }
    if (_settling) {
      if (simulation.isDone(t)) _finish(target: _target);
    } else if (_raw < 1 ||
        _raw > widget.maximum ||
        simulation.dx(t).abs() <= widget.scale / 600) {
      _spring(simulation.dx(t));
    }
  }

  void _finish({int? target}) {
    if (!_busy) return;
    _ticker.stop();
    _pointer = null;
    final result = target ?? DialAdjustment.snap(_raw, widget.maximum);
    if (_moved && widget.onCommit(result, _base, widget.maximum)) {
      _pendingValue = result;
    }
    _draft.value = null;
    if (widget.controller._finish == _finish) {
      widget.controller._finish = null;
      widget.controller.value = false;
    }
  }

  void _semantic(int delta) {
    _finish();
    final base = _pendingValue ?? widget.seconds;
    final next = (base + delta).clamp(1, widget.maximum);
    if (next == base) return;
    if (widget.onCommit(next, base, widget.maximum)) {
      _pendingValue = next;
      _cue(
        DialAdjustment.crossedMinute(base.toDouble(), next.toDouble())
            ? FeedbackCue.dialMinute
            : FeedbackCue.dialSecond,
      );
    }
  }

  @override
  void dispose() {
    // Navigation/lifecycle flush before disposal; never write business state here.
    if (widget.controller._finish == _finish) {
      widget.controller._finish = null;
    }
    motionRouteObserver.unsubscribe(this);
    _lifecycle.dispose();
    _ticker.dispose();
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double?>(
    valueListenable: _draft,
    builder: (context, draft, _) {
      final child = widget.builder(draft);
      if (!widget.enabled) return child;
      return LayoutBuilder(
        builder: (context, constraints) {
          // The artwork retains its theme-specific canvas; width is constrained.
          _size = Size(
            constraints.maxWidth,
            constraints.maxWidth * TS.of(context).artworkAspectRatio,
          );
          return Semantics(
            label: widget.mode == TimerMode.pomodoro ? '本次专注时长' : '倒计时时长',
            value:
                '${durationLabel((draft ?? widget.seconds).round().clamp(1, widget.maximum))}，范围 1 秒至${durationLabel(widget.maximum)}',
            increasedValue: widget.seconds < widget.maximum
                ? durationLabel(widget.seconds + 1)
                : null,
            decreasedValue: widget.seconds > 1
                ? durationLabel(widget.seconds - 1)
                : null,
            onIncrease: widget.seconds < widget.maximum
                ? () => _semantic(1)
                : null,
            onDecrease: widget.seconds > 1 ? () => _semantic(-1) : null,
            child: ExcludeSemantics(
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _ImmediateDialRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _ImmediateDialRecognizer
                      >(
                        _ImmediateDialRecognizer.new,
                        (instance) => instance.onEvent = _event,
                      ),
                },
                child: child,
              ),
            ),
          );
        },
      );
    },
  );
}
