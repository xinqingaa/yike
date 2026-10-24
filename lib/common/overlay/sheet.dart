import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/display/glass_surface.dart';
import 'popup_activity.dart';
import 'popup_theme.dart';
import 'sheet_header.dart';

/// Binds a sheet handle inside the facade so a prebuilt child can finish it.
final class SheetCompletion<T> {
  PopupHandle<T>? _handle;

  void attach(PopupHandle<T> handle) => _handle = handle;

  Future<void> complete([T? value]) {
    final handle = _handle;
    if (handle == null) return Future<void>.value();
    return handle.complete(value);
  }

  Future<void> dismiss() {
    final handle = _handle;
    if (handle == null) return Future<void>.value();
    return handle.dismiss();
  }
}

abstract final class SheetPopup {
  static Future<T?> show<T>({
    String? title,
    required Widget child,
    bool showCloseButton = true,
    SheetDirection direction = SheetDirection.bottom,
    SheetSizeConfig size = const SheetSizeConfig(),
    SheetDragConfig drag = const SheetDragConfig(),
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
    void Function(PopupHandle<T> handle)? attach,
  }) async {
    final context = popupHostContext();
    final ts = TS.of(context);
    final themes = InheritedTheme.capture(from: context, to: null);
    late PopupOpenResult<T> popup;
    popup = Pop.sheet<T>(
      SheetConfig<T>(
        direction: direction,
        useSafeArea: direction == SheetDirection.bottom,
        size: size,
        drag: drag,
        header:
            direction == SheetDirection.bottom ||
                title != null ||
                showCloseButton
            ? SheetHeaderConfig(
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
              )
            : const SheetHeaderConfig(),
        style: PopupTheme.sheetStyle(context, material, direction: direction),
        barrier: PopupBarrierConfig(color: ts.colors.scrim),
        animation: PopupAnimationConfig(
          type: switch (direction) {
            SheetDirection.right => PopupAnimationType.slideRight,
            SheetDirection.left => PopupAnimationType.slideLeft,
            SheetDirection.top => PopupAnimationType.slideDown,
            SheetDirection.bottom => PopupAnimationType.slideUp,
          },
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationSheet,
          slideOffset: 1,
        ),
        builder: (_, _) => themes.wrap(
          Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
    final handle = popup.handleOrNull;
    if (handle != null) attach?.call(handle);
    final result = await popup.result;
    await handle?.dismissed;
    return result;
  }
}
