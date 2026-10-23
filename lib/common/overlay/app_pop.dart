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

export 'sheet_actions.dart';
export 'status_popup.dart' show AppStatusPopup;
export 'sheet_content.dart';

/// Application popup boundary; SDK handles and presentation stay in overlay.
abstract final class AppPop {
  static AppStatusPopup? status(
    BuildContext context, {
    required Widget content,
  }) => AppStatusPopup.show(context, content);

  static void toast(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    double bottomInset = 0,
    String? replacementKey,
  }) => ToastPopup.show(
    context,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    bottomInset: bottomInset,
    replacementKey: replacementKey,
  );

  static Future<void> clearToasts() => ToastPopup.clearToasts();

  static void loading(
    BuildContext context, {
    String? message,
    Future<void>? until,
  }) {
    PopupActivity.modal(
      context,
      () => LoadingPopup.show(context, message: message, until: until),
    );
  }

  static Future<void> hideLoading() => LoadingPopup.hideLoading();

  static Future<T> runLoading<T>(
    BuildContext context, {
    String message = '加载中',
    required Future<T> task,
  }) => LoadingPopup.runLoading<T>(context, message: message, task: task);

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String content = '',
    String confirmText = '确定',
    String cancelText = '取消',
    bool danger = false,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => PopupActivity.modal(
    context,
    () => ConfirmPopup.show(
      context,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      danger: danger,
      material: material,
    ),
  );

  static Future<T?> sheet<T>(
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
  }) => PopupActivity.modal(
    context,
    () => SheetPopup.show<T>(
      context,
      title: title,
      builder: builder,
      showCloseButton: showCloseButton,
      size: size,
      drag: drag,
      material: material,
    ),
  );

  static Future<R?> flowSheet<R>(
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
  }) => PopupActivity.modal(
    context,
    () => FlowSheetPopup.show<R>(
      context,
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

  static Future<T?> dropMenu<T>(
    BuildContext context, {
    required PopupAnchorController anchor,
    required DropMenu<T> menu,
    ValueChanged<T>? onSelected,
    MenuPlacement placement = MenuPlacement.auto,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => PopupActivity.modal(
    context,
    () => MenuPopup.dropMenu<T>(
      context,
      anchor: anchor,
      menu: menu,
      onSelected: onSelected,
      placement: placement,
      material: material,
    ),
  );

  static Future<T?> actionSheet<T>(
    BuildContext context, {
    String? title,
    required List<AppSheetAction<T>> actions,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => PopupActivity.modal(
    context,
    () => MenuPopup.actionSheet<T>(
      context,
      title: title,
      actions: actions,
      material: material,
    ),
  );
}
