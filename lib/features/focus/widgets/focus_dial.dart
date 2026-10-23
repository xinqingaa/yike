import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/clock.dart';
import '../../../common/motion/motion_activity.dart';
import '../../../common/time.dart';
import '../../../common/widgets/yike/dial.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_motion.dart';
import '../logic/focus_projection.dart';
import '../models/focus_data.dart';
import '../models/focus_view.dart';
import '../providers/focus_presentation.dart';

class FocusDial extends ConsumerWidget {
  const FocusDial({super.key, required this.value, required this.width});
  final FocusViewData value;
  final double width;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      focusDataProvider.select(
        (data) => data.session?.mode == value.mode ? data.session : null,
      ),
    );
    return _FocusDialMotion(
      value: value,
      session: session,
      width: width,
      now: ref.watch(clockProvider),
    );
  }
}

class _FocusDialMotion extends StatefulWidget {
  const _FocusDialMotion({
    required this.value,
    required this.session,
    required this.width,
    required this.now,
  });
  final FocusViewData value;
  final FocusSession? session;
  final double width;
  final DateTime Function() now;
  @override
  State<_FocusDialMotion> createState() => _FocusDialMotionState();
}

class _FocusDialMotionState extends State<_FocusDialMotion>
    with TickerProviderStateMixin {
  late final Ticker _frames = createTicker((_) => setState(() {}));
  late final AnimationController _completion = AnimationController(
    vsync: this,
    value: 1,
  );
  bool _active = false, _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active =
        MotionGate.activeOf(context) && TickerMode.valuesOf(context).enabled;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!_active || _reduced) {
      _completion.stop();
      _completion.value = 1;
    }
    _syncFrames();
  }

  @override
  void didUpdateWidget(covariant _FocusDialMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.session, after = widget.session;
    if (before?.id != after?.id || before?.stage != after?.stage) {
      _completion.value = 1;
    } else if (before?.status != TimerStatus.finished &&
        after?.status == TimerStatus.finished) {
      if (_active && !_reduced) {
        _completion.duration = TS.of(context).motion.durationSlow;
        _completion.forward(from: 0);
      }
    }
    _syncFrames();
  }

  void _syncFrames() {
    final running =
        _active && !_reduced && widget.session?.status == TimerStatus.running;
    if (running && !_frames.isActive) _frames.start();
    if (!running && _frames.isActive) _frames.stop();
  }

  @override
  void dispose() {
    _frames.dispose();
    _completion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projection = FocusProjection.at(
      widget.session,
      widget.value,
      widget.now(),
    );
    final running =
        widget.session?.status == TimerStatus.running && _active && !_reduced;
    final second = projection.elapsedSeconds % 1;
    final minute = projection.elapsedSeconds % 60;
    final beat = running
        ? math.max(0, 1 - second / YikeMotion.secondWindow) *
                  YikeMotion.secondStrength +
              (projection.elapsedSeconds >= 60
                  ? math.max(0, 1 - minute / YikeMotion.minuteWindow) *
                        YikeMotion.minuteStrength
                  : 0)
        : 0.0;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _completion,
        builder: (context, _) => Transform.scale(
          key: const ValueKey('focus-completion-motion'),
          scale:
              1 +
              math.sin(_completion.value * math.pi) *
                  YikeMotion.completionScale,
          child: YikeDial(
            width: widget.width,
            digits: timerDigits(projection.seconds),
            caption: widget.value.caption,
            progress: projection.progress,
            paused: widget.value.paused,
            resting: widget.value.resting,
            completed: widget.value.finished,
            countdown: widget.value.mode == TimerMode.countdown,
            animateDigits: running,
            digitIdentity: '${widget.session?.id}/${widget.session?.stage}',
            descending: widget.value.mode != TimerMode.stopwatch,
            beat: beat,
            wavePhase: running ? second : 0,
          ),
        ),
      ),
    );
  }
}
