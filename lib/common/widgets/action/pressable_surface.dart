import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/ts.dart';
import '../../state/local_value.dart';

/// A themed action whose feedback paints above opaque artwork and child surfaces.
class CommonPressableSurface extends ConsumerStatefulWidget {
  const CommonPressableSurface({
    super.key,
    required this.child,
    required this.onPressed,
    this.shape,
    this.focusNode,
    this.selected,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final OutlinedBorder? shape;
  final FocusNode? focusNode;
  final bool? selected;

  @override
  ConsumerState<CommonPressableSurface> createState() =>
      _CommonPressableSurfaceState();
}

class _CommonPressableSurfaceState
    extends ConsumerState<CommonPressableSurface> {
  final _pressed = localValueProvider(false);
  final _focusVisible = localValueProvider(false);

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final enabled = widget.onPressed != null;
    final pressed = ref.watch(_pressed) && enabled;
    final focused =
        ref.watch(_focusVisible) &&
        enabled &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final shape =
        widget.shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ts.radius.md),
        );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationFast,
          curve: ts.motion.easingStandard,
          foregroundDecoration: ShapeDecoration(
            color: ts.colors.primary.withValues(
              alpha: pressed ? ts.opacity.pressed : 0,
            ),
            shape: focused
                ? shape.copyWith(side: ts.border.focus)
                : shape.copyWith(side: BorderSide.none),
          ),
          child: InkWell(
            focusNode: widget.focusNode,
            canRequestFocus: enabled,
            onTap: widget.onPressed,
            customBorder: shape,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            onHighlightChanged: (value) =>
                ref.read(_pressed.notifier).set(value),
            onFocusChange: (value) => ref
                .read(_focusVisible.notifier)
                .set(
                  value &&
                      FocusManager.instance.highlightMode ==
                          FocusHighlightMode.traditional,
                ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
