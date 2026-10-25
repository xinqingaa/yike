import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/clock.dart';
import '../features/focus/focus_models.dart';
import '../theme/ts.dart';
import '../theme/yike_motion.dart';

/// Frame-only rendering: the sweep never advances or settles a session.
class TimerStatusProgress extends ConsumerStatefulWidget {
  const TimerStatusProgress({
    super.key,
    required this.session,
    required this.active,
    required this.completed,
    this.height,
  });
  final FocusSession session;
  final bool active, completed;
  final double? height;
  @override
  ConsumerState<TimerStatusProgress> createState() =>
      _TimerStatusProgressState();
}

class _TimerStatusProgressState extends ConsumerState<TimerStatusProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this);
  Duration? _period;

  void _sync() {
    final enabled =
        widget.active &&
        !widget.completed &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    final period = widget.session.status == TimerStatus.paused
        ? YikeMotion.statusPausedSweep
        : YikeMotion.statusSweep;
    if (!enabled) {
      _sweep.stop();
    } else if (!_sweep.isAnimating || _period != period) {
      _sweep.repeat(period: period);
    }
    _period = period;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TimerStatusProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: widget.height ?? ts.sizing.progressTrack,
        child: CustomPaint(
          painter: _ProgressPainter(
            session: widget.session,
            now: ref.watch(clockProvider),
            sweep: _sweep,
            completed: widget.completed,
            animate: widget.active && !MediaQuery.disableAnimationsOf(context),
            primary: ts.colors.primary,
            track: ts.colors.primarySoft,
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.session,
    required this.now,
    required this.sweep,
    required this.completed,
    required this.animate,
    required this.primary,
    required this.track,
  }) : view = FocusData(
         sessions: {session.mode: session},
         mode: session.mode,
       ).view,
       super(repaint: sweep);
  final FocusSession session;
  final FocusViewData view;
  final DateTime Function() now;
  final AnimationController sweep;
  final bool completed, animate;
  final Color primary, track;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final projection = FocusProjection.at(session, view, now());
    final progress = completed
        ? 1.0
        : (projection.elapsedSeconds * 1000 / session.limitMs).clamp(0.0, 1.0);
    final paused = session.status == TimerStatus.paused;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(bounds, Radius.circular(size.height / 2)),
    );
    canvas.drawRect(bounds, Paint()..color = track);
    final edge = size.width * progress;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, edge, size.height),
      Paint()..color = primary,
    );
    if (!completed && edge < size.width) {
      final remaining = Rect.fromLTRB(edge, 0, size.width, size.height);
      if (paused) {
        canvas.drawRect(
          remaining,
          Paint()..color = primary.withValues(alpha: .12),
        );
      }
      if (animate) {
        canvas.clipRect(remaining);
        final beam = size.width * (paused ? .45 : .24);
        final x = edge + (remaining.width + beam) * sweep.value - beam;
        final rect = Rect.fromLTWH(x, 0, beam, size.height);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                primary.withValues(alpha: 0),
                primary.withValues(alpha: paused ? .58 : .26),
                primary.withValues(alpha: 0),
              ],
              stops: const [0, .5, 1],
            ).createShader(rect),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) =>
      session != oldDelegate.session ||
      completed != oldDelegate.completed ||
      animate != oldDelegate.animate ||
      primary != oldDelegate.primary ||
      track != oldDelegate.track ||
      now != oldDelegate.now;
}
