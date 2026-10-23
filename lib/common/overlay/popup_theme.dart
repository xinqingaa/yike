import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/display/glass_surface.dart';

abstract final class PopupTheme {
  static PopupSurface surface(
    BuildContext context,
    CommonSurfaceMaterial material,
  ) {
    if (material == CommonSurfaceMaterial.solid ||
        MediaQuery.highContrastOf(context)) {
      return const PopupSurface.solid();
    }
    return PopupSurface.glass(style: TS.of(context).glassStyle());
  }

  static SheetStyle sheetStyle(
    BuildContext context,
    CommonSurfaceMaterial material,
  ) {
    final ts = TS.of(context);
    return SheetStyle(
      backgroundColor: ts.colors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(ts.radius.xl)),
      padding: EdgeInsets.fromLTRB(
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
