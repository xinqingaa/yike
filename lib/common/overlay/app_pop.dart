import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../widgets/display/glass_surface.dart';
import 'popup_activity.dart';
import 'status_popup.dart';
import 'confirm.dart';
import 'flow_sheet.dart';
import 'loading.dart';
import 'menu.dart';
import 'sheet.dart';
import 'sheet_actions.dart';
import 'toast.dart';

export 'package:unified_popups/unified_popups.dart'
    show
        DropMenu,
        DropMenuItem,
        FlowSheetController,
        FlowSheetPage,
        MenuPlacement,
        PopupAnchor,
        PopupAnchorController,
        SheetDimension,
        SheetDirection,
        SheetDragConfig,
        SheetSizeConfig;
export 'data_card.dart';
export 'sheet_actions.dart';
export 'status_popup.dart' show AppStatusPopup;
export 'sheet_content.dart';

/// Application popup boundary. Pages pass a child; SDK handles stay here.
abstract final class AppPop {
  static AppStatusPopup? status({required Widget content}) =>
      AppStatusPopup.show(content);

  static void toast(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    double bottomInset = 0,
    String? replacementKey,
  }) => ToastPopup.show(
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
    bottomInset: bottomInset,
    replacementKey: replacementKey,
  );

  static Future<void> clearToasts() => ToastPopup.clearToasts();

  static void loading({String? message, Future<void>? until}) {
    PopupActivity.modal(
      () => LoadingPopup.show(message: message, until: until),
    );
  }

  static Future<void> hideLoading() => LoadingPopup.hideLoading();

  static Future<T> runLoading<T>({
    String message = '加载中',
    required Future<T> task,
  }) => LoadingPopup.runLoading<T>(message: message, task: task);

  static Future<bool> confirm({
    required String title,
    String content = '',
    String confirmText = '确定',
    String cancelText = '取消',
    bool danger = false,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => PopupActivity.modal(
    () => ConfirmPopup.show(
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      danger: danger,
      material: material,
    ),
  );

  static Future<T?> sheet<T>({
    String? title,
    required Widget child,
    bool showCloseButton = true,
    SheetDirection direction = SheetDirection.bottom,
    SheetSizeConfig size = const SheetSizeConfig(),
    SheetDragConfig drag = const SheetDragConfig(),
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => _openSheet<T>(
    title: title,
    child: child,
    showCloseButton: showCloseButton,
    direction: direction,
    size: size,
    drag: drag,
    material: material,
  );

  static Future<T?> _openSheet<T>({
    String? title,
    required Widget child,
    bool showCloseButton = true,
    SheetDirection direction = SheetDirection.bottom,
    SheetSizeConfig size = const SheetSizeConfig(),
    SheetDragConfig drag = const SheetDragConfig(),
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
    bool timerPanel = false,
    void Function(PopupHandle<T> handle)? attach,
  }) => PopupActivity.modal(
    () => SheetPopup.show<T>(
      title: title,
      child: child,
      showCloseButton: showCloseButton,
      direction: direction,
      size: size,
      drag: drag,
      material: material,
      attach: attach,
    ),
    timerPanel: timerPanel,
  );

  static Future<R?> flowSheet<R>({
    required FlowSheetController<R> controller,
    required FlowSheetPage initialPage,
    String? title,
    bool showCloseButton = true,
    Widget? headerStart,
    Map<String, String> pageTitles = const {},
    SheetSizeConfig size = const SheetSizeConfig(),
    SheetDragConfig drag = const SheetDragConfig(
      mode: SheetDragDismissMode.handleOnly,
    ),
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => PopupActivity.modal(
    () => FlowSheetPopup.show<R>(
      controller: controller,
      initialPage: initialPage,
      title: title,
      showCloseButton: showCloseButton,
      headerStart: headerStart,
      pageTitles: pageTitles,
      size: size,
      drag: drag,
      material: material,
    ),
  );

  static Future<T?> dropMenu<T>({
    required PopupAnchorController anchor,
    required DropMenu<T> menu,
    ValueChanged<T>? onSelected,
    MenuPlacement placement = MenuPlacement.auto,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => PopupActivity.modal(
    () => MenuPopup.dropMenu<T>(
      anchor: anchor,
      menu: menu,
      onSelected: onSelected,
      placement: placement,
      material: material,
    ),
  );

  static Future<T?> actionSheet<T>({
    String? title,
    required List<AppSheetAction<T>> actions,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => PopupActivity.modal(
    () => MenuPopup.actionSheet<T>(
      title: title,
      actions: actions,
      material: material,
    ),
  );
}

/// Sheet the caller can finish from a button inside [show]'s child.
final class AppSheet<T> {
  final _completion = SheetCompletion<T>();

  Future<void> complete([T? value]) => _completion.complete(value);

  Future<void> dismiss() => _completion.dismiss();

  Future<T?> show({
    bool timerPanel = false,
    String? title,
    required Widget child,
    bool showCloseButton = true,
    SheetDirection direction = SheetDirection.bottom,
    SheetSizeConfig size = const SheetSizeConfig(),
    SheetDragConfig drag = const SheetDragConfig(),
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => AppPop._openSheet<T>(
    title: title,
    child: child,
    showCloseButton: showCloseButton,
    direction: direction,
    size: size,
    drag: drag,
    material: material,
    timerPanel: timerPanel,
    attach: _completion.attach,
  );
}
