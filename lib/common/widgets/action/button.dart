import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/local_value.dart';

import '../../../theme/ts.dart';
import '../display/glass_surface.dart';

enum CommonButtonKind { primary, secondary, outlined, accent, danger, quiet }

enum CommonControlSize { sm, md, lg }

enum CommonButtonShape { rounded, pill }

class CommonButton extends ConsumerStatefulWidget {
  const CommonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = CommonButtonKind.primary,
    this.size = CommonControlSize.md,
    this.loading = false,
    this.block = false,
    this.disabled = false,
    this.shape = CommonButtonShape.rounded,
    this.material = CommonSurfaceMaterial.solid,
  });

  final String label;
  final VoidCallback? onPressed;
  final CommonButtonKind kind;
  final CommonControlSize size;
  final bool loading;
  final bool block;
  final bool disabled;
  final CommonButtonShape shape;
  final CommonSurfaceMaterial material;

  @override
  ConsumerState<CommonButton> createState() => _CommonButtonState();
}

class _CommonButtonState extends ConsumerState<CommonButton> {
  final _pressedProvider = localValueProvider(false);

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final pressed = ref.watch(_pressedProvider);
    final enabled =
        !widget.disabled && !widget.loading && widget.onPressed != null;
    final height = switch (widget.size) {
      CommonControlSize.sm => ts.sizing.controlSm,
      CommonControlSize.md => ts.sizing.controlMd,
      CommonControlSize.lg => ts.sizing.controlLg,
    };
    final background = switch (widget.kind) {
      CommonButtonKind.primary => ts.colors.action,
      CommonButtonKind.secondary => ts.colors.actionSoft,
      CommonButtonKind.accent => ts.colors.primary,
      CommonButtonKind.danger => ts.colors.error,
      CommonButtonKind.outlined || CommonButtonKind.quiet => Colors.transparent,
    };
    final foreground = switch (widget.kind) {
      CommonButtonKind.primary => ts.colors.onAction,
      CommonButtonKind.secondary => ts.colors.action,
      CommonButtonKind.accent => ts.colors.onPrimary,
      CommonButtonKind.danger => ts.colors.onError,
      CommonButtonKind.outlined ||
      CommonButtonKind.quiet => ts.colors.onSurface,
    };
    final radius = BorderRadius.circular(
      widget.shape == CommonButtonShape.pill ? ts.radius.full : ts.radius.md,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Widget content = SizedBox(
      width: widget.block ? double.infinity : null,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? widget.onPressed : null,
          onHighlightChanged: (value) {
            ref.read(_pressedProvider.notifier).set(value);
          },
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: widget.material == CommonSurfaceMaterial.glass
                  ? Colors.transparent
                  : background,
              borderRadius: radius,
              border: widget.kind == CommonButtonKind.quiet
                  ? null
                  : Border.all(
                      color: widget.kind == CommonButtonKind.outlined
                          ? ts.colors.outline
                          : background,
                      width: ts.border.widthHairline,
                    ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ts.spacing.md),
              child: Center(
                widthFactor: widget.block ? null : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading) ...[
                      SizedBox(
                        width: ts.sizing.iconSm,
                        height: ts.sizing.iconSm,
                        child: CircularProgressIndicator(
                          strokeWidth: ts.sizing.progressStroke,
                          color: foreground,
                        ),
                      ),
                      SizedBox(width: ts.spacing.sm),
                    ],
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : ts.motion.durationFast,
                        child: Text(
                          widget.label,
                          key: ValueKey(widget.label),
                          style:
                              (widget.size == CommonControlSize.sm
                                      ? ts.textStyle.captionStrong
                                      : ts.textStyle.label)
                                  .copyWith(color: foreground),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.material == CommonSurfaceMaterial.glass) {
      content = CommonGlassSurface(
        borderRadius: radius,
        tint: widget.kind == CommonButtonKind.primary
            ? ts.colors.buttonGlassPrimaryTint
            : background,
        child: content,
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: widget.disabled ? ts.opacity.disabled : ts.opacity.visible,
        child: AnimatedScale(
          scale: pressed && enabled && !reduceMotion
              ? ts.motion.scalePressed
              : ts.opacity.visible,
          duration: reduceMotion ? Duration.zero : ts.motion.durationFast,
          curve: ts.motion.easingStandard,
          child: content,
        ),
      ),
    );
  }
}
