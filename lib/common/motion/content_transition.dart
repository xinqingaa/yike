import 'package:flutter/material.dart';

import '../../theme/ts.dart';
import '../../theme/yike_motion.dart';
import 'motion_activity.dart';

bool motionEnabled(BuildContext context) =>
    !MediaQuery.disableAnimationsOf(context) &&
    MotionGate.activeOf(context) &&
    TickerMode.valuesOf(context).enabled;

/// Latest content owns input and semantics, including while an old child exits.
class MotionContent extends StatefulWidget {
  const MotionContent({
    super.key,
    required this.child,
    this.identity,
    this.direction = 0,
    this.resize = true,
    this.alignment = Alignment.topCenter,
  });
  final Widget child;
  final Object? identity;
  final double direction;
  final bool resize;
  final Alignment alignment;

  @override
  State<MotionContent> createState() => _MotionContentState();
}

class _MotionContentState extends State<MotionContent> {
  GlobalKey _current = GlobalKey();
  @override
  void didUpdateWidget(covariant MotionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) _current = GlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final enabled = motionEnabled(context);
    final current = KeyedSubtree(key: _current, child: widget.child);
    final content = enabled
        ? AnimatedSwitcher(
            duration: ts.motion.durationNormal,
            switchInCurve: ts.motion.easingStandard,
            switchOutCurve: ts.motion.easingStandard,
            layoutBuilder: (current, previous) => Stack(
              alignment: widget.alignment,
              children: [
                for (final old in previous)
                  IgnorePointer(
                    child: ExcludeFocus(child: ExcludeSemantics(child: old)),
                  ),
                ?current,
              ],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) => FractionalTranslation(
                  translation: Offset(
                    widget.direction *
                        YikeMotion.contentTravel *
                        (animation.status == AnimationStatus.reverse
                            ? animation.value - 1
                            : 1 - animation.value),
                    0,
                  ),
                  child: child,
                ),
              ),
            ),
            child: KeyedSubtree(key: ValueKey(widget.identity), child: current),
          )
        : current;
    return widget.resize
        ? MotionSize(alignment: widget.alignment, child: content)
        : content;
  }
}

/// Layout interpolation keeps the actual child (and its draft/focus) mounted.
class MotionSize extends StatefulWidget {
  const MotionSize({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });
  final Widget child;
  final Alignment alignment;
  @override
  State<MotionSize> createState() => _MotionSizeState();
}

class _MotionSizeState extends State<MotionSize> {
  final _content = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _content, child: widget.child);
    if (!motionEnabled(context)) return child;
    final ts = TS.of(context);
    return AnimatedSize(
      duration: ts.motion.durationNormal,
      curve: ts.motion.easingStandard,
      alignment: widget.alignment,
      child: child,
    );
  }
}

/// Collapsed content immediately loses input, focus and semantics.
class MotionExpand extends StatelessWidget {
  const MotionExpand({
    super.key,
    required this.expanded,
    required this.child,
    this.alignment = Alignment.topLeft,
  });
  final bool expanded;
  final Widget child;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => MotionSize(
    alignment: alignment,
    child: ClipRect(
      child: Align(
        alignment: alignment,
        heightFactor: expanded ? 1 : 0,
        child: IgnorePointer(
          ignoring: !expanded,
          child: ExcludeFocus(
            excluding: !expanded,
            child: ExcludeSemantics(excluding: !expanded, child: child),
          ),
        ),
      ),
    ),
  );
}
