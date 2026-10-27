import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/display/glass_surface.dart';

abstract final class PopupTheme {
  static PopupSurface surface(
    BuildContext context,
    CommonSurfaceMaterial material,
  ) {
    if (material == CommonSurfaceMaterial.solid) {
      return const PopupSurface.solid();
    }
    return PopupSurface.builder(
      (context, slot) => CommonGlassSurface(
        borderRadius: slot.borderRadius,
        backdropBlendMode: BlendMode.src,
        child: slot.child,
      ),
    );
  }

  static SheetStyle sheetStyle(
    BuildContext context,
    CommonSurfaceMaterial material, {
    SheetDirection direction = SheetDirection.bottom,
  }) {
    final ts = TS.of(context);
    return SheetStyle(
      backgroundColor: ts.colors.surface,
      borderRadius: switch (direction) {
        SheetDirection.right => BorderRadius.horizontal(
          left: Radius.circular(ts.radius.xl),
        ),
        SheetDirection.left => BorderRadius.horizontal(
          right: Radius.circular(ts.radius.xl),
        ),
        SheetDirection.top => BorderRadius.vertical(
          bottom: Radius.circular(ts.radius.xl),
        ),
        SheetDirection.bottom => BorderRadius.vertical(
          top: Radius.circular(ts.radius.xl),
        ),
      },
      padding: direction == SheetDirection.right
          ? EdgeInsets.zero
          : EdgeInsets.fromLTRB(
              ts.spacing.md,
              ts.spacing.sm,
              ts.spacing.md,
              ts.spacing.md,
            ),
      boxShadow: [ts.elevation.overlay],
      surface: surface(context, material),
    );
  }
}
