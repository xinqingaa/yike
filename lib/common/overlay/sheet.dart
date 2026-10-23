import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/display/glass_surface.dart';
import 'popup_theme.dart';
import 'sheet_header.dart';
import 'sheet_actions.dart';

abstract final class SheetPopup {
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required Widget Function(BuildContext context, AppSheetActions<T> actions)
    builder,
    bool showCloseButton = true,
    SheetSizeConfig size = const SheetSizeConfig(
      maxHeight: SheetDimension.fraction(1),
    ),
    SheetDragConfig drag = const SheetDragConfig(),
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) async {
    final ts = TS.of(context);
    final themes = InheritedTheme.capture(from: context, to: null);
    late PopupOpenResult<T> popup;
    popup = Pop.sheet<T>(
      SheetConfig<T>(
        size: size,
        drag: drag,
        header: SheetHeaderConfig(
          padding: EdgeInsets.only(bottom: ts.spacing.sm),
          titleWidget: themes.wrap(
            Material(
              type: MaterialType.transparency,
              child: AppSheetHeader(
                title: title ?? '',
                close: showCloseButton
                    ? () => popup.handleOrNull?.dismiss()
                    : null,
              ),
            ),
          ),
          showCloseButton: false,
        ),
        style: PopupTheme.sheetStyle(context, material),
        barrier: PopupBarrierConfig(color: ts.colors.scrim),
        animation: PopupAnimationConfig(
          type: PopupAnimationType.slideUp,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationSheet,
          slideOffset: 1,
        ),
        builder: (_, handle) => themes.wrap(
          Material(
            type: MaterialType.transparency,
            child: Builder(
              builder: (context) => builder(context, AppSheetActions(handle)),
            ),
          ),
        ),
      ),
    );
    final result = await popup.result;
    await popup.handleOrNull?.dismissed;
    return result;
  }
}
