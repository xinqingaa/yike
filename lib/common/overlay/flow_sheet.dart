import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/action/icon.dart';
import '../widgets/action/icon_button.dart';
import '../widgets/display/glass_surface.dart';
import 'popup_theme.dart';
import 'sheet_header.dart';

abstract final class FlowSheetPopup {
  static Future<R?> show<R>(
    BuildContext context, {
    required FlowSheetController<R> controller,
    required FlowSheetPage initialPage,
    String? title,
    bool showCloseButton = true,
    Widget? headerStart,
    Map<String, String> pageTitles = const {},
    SheetSizeConfig? size,
    SheetDragConfig drag = const SheetDragConfig(
      mode: SheetDragDismissMode.handleOnly,
    ),
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) async {
    final ts = TS.of(context);
    final themes = InheritedTheme.capture(from: context, to: null);
    late PopupOpenResult<R> popup;
    popup = Pop.flowSheet<R>(
      FlowSheetConfig<R>(
        controller: controller,
        initialPage: initialPage,
        header: SheetHeaderConfig(
          padding: EdgeInsets.only(bottom: ts.spacing.sm),
          titleWidget: themes.wrap(
            Material(
              type: MaterialType.transparency,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => AppSheetHeader(
                  title: controller.canPop
                      ? (pageTitles[controller.entries.last.page.id] ??
                            title ??
                            '')
                      : title ?? '',
                  start: controller.canPop
                      ? CommonIconButton(
                          name: CommonIconName.chevronLeft,
                          label: '返回上一步',
                          variant: CommonIconButtonVariant.tonal,
                          onPressed: controller.handleBack,
                        )
                      : headerStart,
                  close: showCloseButton
                      ? () => popup.handleOrNull?.dismiss()
                      : null,
                ),
              ),
            ),
          ),
          showCloseButton: false,
        ),
        style: PopupTheme.sheetStyle(context, material),
        size:
            size ??
            const SheetSizeConfig(maxHeight: SheetDimension.fraction(1)),
        drag: drag,
        animation: PopupAnimationConfig(
          type: PopupAnimationType.slideUp,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationSheet,
          slideOffset: 1,
        ),
        barrier: PopupBarrierConfig(color: ts.colors.scrim),
      ),
    );
    final result = await popup.result;
    await popup.handleOrNull?.dismissed;
    return result;
  }
}
