import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motion/content_transition.dart';
import '../../../common/motion/motion_activity.dart';
import '../providers/habits_presentation.dart';
import '../../../theme/ts.dart';
import '../../../theme/yike_motion.dart';

/// Feedback consumes accepted operations without replaying historical facts.
class CheckinFeedback extends ConsumerStatefulWidget {
  const CheckinFeedback({
    super.key,
    required this.checked,
    required this.habitId,
    required this.child,
  });
  final bool checked;
  final String habitId;
  final Widget child;
  @override
  ConsumerState<CheckinFeedback> createState() => _CheckinFeedbackState();
}

class _CheckinFeedbackState extends ConsumerState<CheckinFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    value: 1,
  );
  bool _enabled = false;
  bool? _animatedChecked;

  @override
  void initState() {
    super.initState();
    ref.listenManual(habitFeedbackProvider, (_, event) {
      if (event == null || event.habitId != widget.habitId) return;
      _animatedChecked = event.checked;
      if (!MotionGate.activeNowOf(context) ||
          !_enabled ||
          event.kind == HabitFeedbackKind.restored) {
        _motion.value = 1;
      } else if (event.kind == HabitFeedbackKind.added) {
        _motion.forward(from: _motion.isAnimating ? _motion.value : 0);
      } else {
        _motion.reverse();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = motionEnabled(context);
    _motion.duration = TS.of(context).motion.durationFast;
    if (!_enabled) _motion.value = 1;
  }

  @override
  void didUpdateWidget(covariant CheckinFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habitId != widget.habitId ||
        (oldWidget.checked != widget.checked &&
            _animatedChecked != widget.checked)) {
      _motion.value = 1;
    }
    _animatedChecked = null;
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final water = ts.pack.id.endsWith('water');
    final sundial = ts.pack.id.endsWith('sundial');
    return AnimatedBuilder(
      animation: _motion,
      child: widget.child,
      builder: (context, child) {
        final pulse = math.sin(_motion.value * math.pi);
        return Stack(
          alignment: Alignment.center,
          children: [
            if (water && _motion.isAnimating)
              IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    size: Size.square(ts.sizing.touch),
                    painter: _Drop(_motion.value, ts),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, water ? -ts.spacing.sm * pulse : 0),
              child: Transform.rotate(
                angle: sundial ? -YikeMotion.checkinScale * pulse : 0,
                child: Transform.scale(
                  key: const ValueKey('checkin-feedback-motion'),
                  scale: 1 - YikeMotion.checkinScale * pulse,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Drop extends CustomPainter {
  const _Drop(this.phase, this.ts);
  final double phase;
  final TS ts;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ink = Paint()..color = ts.colors.primary.withValues(alpha: 1 - phase);
    if (phase < .5) {
      canvas.drawCircle(
        center.translate(0, -size.height * (.5 - phase)),
        ts.spacing.xxs,
        ink,
      );
    } else {
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts.border.widthHairline;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * phase,
          height: size.height * phase / 3,
        ),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(_Drop old) => old.phase != phase || old.ts != ts;
}
