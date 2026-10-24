import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/clock.dart';
import '../../../common/motion/dial_frame.dart';
import '../../../common/motion/motion_activity.dart';
import '../../../common/time.dart';
import '../../../common/widgets/yike/dial.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_motion.dart';
import '../logic/focus_projection.dart';
import '../models/focus_data.dart';
import '../models/focus_view.dart';
import '../providers/focus_dial_presentation.dart';
import '../providers/focus_presentation.dart';
import 'dial_adjuster.dart';

class FocusDial extends ConsumerStatefulWidget {
  const FocusDial({
    super.key,
    required this.mode,
    required this.width,
    required this.adjustment,
  });
  final TimerMode mode;
  final double width;
  final DialAdjustmentController adjustment;
  @override
  ConsumerState<FocusDial> createState() => _FocusDialState();
}

class _FocusDialState extends ConsumerState<FocusDial> {
  final _completion = ValueNotifier<FocusCompletion?>(null);
  StreamSubscription<FocusCompletion>? _subscription;
  @override
  void initState() {
    super.initState();
    ref.listenManual(focusCompletionEventsProvider, (_, events) {
      unawaited(_subscription?.cancel());
      _subscription = events.listen(_completed);
    }, fireImmediately: true);
  }

  void _completed(FocusCompletion event) {
    if (MotionGate.activeNowOf(context) &&
        widget.mode == event.mode &&
        !MediaQuery.disableAnimationsOf(context)) {
      _completion.value = event;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _completion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = ref.watch(focusDialPresentationProvider(widget.mode));
    final mode = ref.watch(focusDataProvider.select((d) => d.mode));
    final countdownMaximum = ref.watch(
      focusDataProvider.select((d) => d.countdownMaximum),
    );
    final dialAdjusted = ref.watch(
      focusDataProvider.select((d) => d.dialAdjusted),
    );
    final now = ref.watch(clockProvider);
    final enabled =
        presentation.view.ready &&
        widget.mode != TimerMode.stopwatch &&
        mode == widget.mode;
    return SizedBox(
      width: widget.width,
      child: DialAdjuster(
        mode: widget.mode,
        seconds: presentation.view.seconds,
        maximum: widget.mode == TimerMode.countdown
            ? countdownMaximum
            : maxFocusSeconds,
        scale: presentation.view.scaleSeconds,
        enabled: enabled,
        controller: widget.adjustment,
        onCommit: (seconds, expected, maximum) => ref
            .read(focusActionsProvider)
            .adjustDial(
              widget.mode,
              seconds,
              expectedValue: expected,
              expectedMaximum: maximum,
            ),
        builder: (draft) => _FocusDialMotion(
          data: presentation,
          width: widget.width,
          completions: _completion,
          now: now,
          draft: draft,
          hint: enabled && !dialAdjusted,
        ),
      ),
    );
  }
}

class _FocusDialMotion extends StatefulWidget {
  const _FocusDialMotion({
    required this.data,
    required this.width,
    required this.now,
    required this.completions,
    this.draft,
    this.hint = false,
  });
  final FocusDialPresentation data;
  final double? draft;
  final bool hint;
  FocusViewData get value => data.view;
  FocusSession? get session => data.session;
  final double width;
  final ValueListenable<FocusCompletion?> completions;
  final DateTime Function() now;
  @override
  State<_FocusDialMotion> createState() => _FocusDialMotionState();
}

class _FocusDialMotionState extends State<_FocusDialMotion>
    with TickerProviderStateMixin {
  late final Ticker _frames = createTicker((_) => _project());
  late final ValueNotifier<DialFrame> _frame = ValueNotifier(
    DialFrame(progress: widget.value.progress),
  );
  final _seconds = ValueNotifier<int?>(null);

  void _project() {
    final projection = FocusProjection.at(
      widget.session,
      widget.value,
      widget.now(),
    );
    final running =
        widget.session?.status == TimerStatus.running && _active && !_reduced;
    final second = projection.elapsedSeconds % 1;
    final minute = projection.elapsedSeconds % 60;
    _frame.value = DialFrame(
      progress: widget.draft == null
          ? projection.progress
          : widget.draft! / widget.value.scaleSeconds,
      secondBeat: running
          ? math.max(0, 1 - second / YikeMotion.secondWindow) *
                YikeMotion.secondStrength
          : 0,
      minuteBeat: running && projection.elapsedSeconds >= 60
          ? math.max(0, 1 - minute / YikeMotion.minuteWindow) *
                YikeMotion.minuteStrength
          : 0,
      wavePhase: running ? second : 0,
    );
    _seconds.value = projection.seconds;
  }

  late final AnimationController _completion = AnimationController(
    vsync: this,
    value: 1,
  );
  bool _active = false, _reduced = false;

  @override
  void initState() {
    super.initState();
    widget.completions.addListener(_complete);
  }

  void _complete() {
    final event = widget.completions.value;
    if (!_active ||
        _reduced ||
        event == null ||
        event.sessionId != widget.session?.id ||
        event.stage != widget.session?.stage) {
      return;
    }
    _completion.duration = TS.of(context).motion.durationSlow;
    _completion.forward(from: 0);
  }

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
    _project();
    _syncFrames();
  }

  @override
  void didUpdateWidget(covariant _FocusDialMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.session, after = widget.session;
    if (before?.id != after?.id || before?.stage != after?.stage) {
      _completion.value = 1;
    }
    _project();
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
    widget.completions.removeListener(_complete);
    _frames.dispose();
    _frame.dispose();
    _seconds.dispose();
    _completion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running =
        widget.session?.status == TimerStatus.running && _active && !_reduced;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _completion,
        builder: (context, child) => Transform.scale(
          key: const ValueKey('focus-completion-motion'),
          scale:
              1 +
              math.sin(_completion.value * math.pi) *
                  YikeMotion.completionScale,
          child: child,
        ),
        child: ValueListenableBuilder<int?>(
          valueListenable: _seconds,
          builder: (context, _, _) {
            final projection = FocusProjection.at(
              widget.session,
              widget.value,
              widget.now(),
            );
            return YikeDial(
              width: widget.width,
              digits: timerDigits(
                widget.draft?.round().clamp(1, maxFocusSeconds) ??
                    projection.seconds,
              ),
              hint: widget.hint ? '拨动表盘调整本次时长' : null,
              caption: widget.value.caption,
              progress: widget.draft == null
                  ? projection.progress
                  : widget.draft! / widget.value.scaleSeconds,
              paused: widget.value.paused,
              resting: widget.value.resting,
              completed: widget.value.finished,
              countdown: widget.value.mode == TimerMode.countdown,
              animateDigits: running,
              digitIdentity: '${widget.session?.id}/${widget.session?.stage}',
              descending: widget.value.mode != TimerMode.stopwatch,
              frame: _frame,
            );
          },
        ),
      ),
    );
  }
}
