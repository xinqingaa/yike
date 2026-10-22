import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/action/button.dart';
import '../widgets/action/icon.dart';
import '../widgets/action/icon_button.dart';
import '../widgets/display/glass_surface.dart';

/// Shared popup boundary. Context selects the caller's theme; the library owns
/// overlay placement, back handling, keyboard, drag and lifetime.
abstract final class AppPop {
  static PopupSurface _surface(
    BuildContext context,
    CommonSurfaceMaterial material,
  ) {
    if (material == CommonSurfaceMaterial.solid ||
        MediaQuery.highContrastOf(context)) {
      return const PopupSurface.solid();
    }
    return PopupSurface.glass(style: TS.of(context).glassStyle());
  }

  static SheetStyle _sheetStyle(
    BuildContext context,
    CommonSurfaceMaterial material,
  ) {
    final ts = TS.of(context);
    return SheetStyle(
      backgroundColor: ts.colors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(ts.radius.xl)),
      padding: EdgeInsets.fromLTRB(0, ts.spacing.sm, 0, ts.spacing.md),
      boxShadow: [ts.elevation.overlay],
      surface: _surface(context, material),
    );
  }

  static void toast(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    double bottomInset = 0,
  }) {
    assert((actionLabel == null) == (onAction == null));
    final ts = TS.of(context);
    final style = ToastStyle(
      padding: EdgeInsets.symmetric(
        horizontal: ts.spacing.md,
        vertical: ts.spacing.toastGap,
      ),
      margin: EdgeInsets.fromLTRB(
        ts.spacing.md,
        ts.spacing.md,
        ts.spacing.md,
        ts.spacing.md + bottomInset,
      ),
      decoration: BoxDecoration(
        color: ts.colors.toast,
        borderRadius: BorderRadius.circular(ts.radius.md),
      ),
      textStyle: ts.textStyle.content.copyWith(color: ts.colors.onToast),
      spacing: ts.spacing.sm,
    );
    final lifetime = PopupLifetime.after(ts.motion.durationToast);
    if (actionLabel == null) {
      Pop.toast(
        ToastConfig.text(
          message,
          type: ToastType.none,
          position: PopupPosition.bottom,
          style: style,
          lifetime: lifetime,
        ),
      );
      return;
    }
    PopupHandle<void>? handle;
    var acted = false;
    final opened = Pop.toast(
      ToastConfig.content(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(message, style: style.textStyle)),
            SizedBox(width: ts.spacing.sm),
            TextButton(
              onPressed: () {
                if (acted) return;
                acted = true;
                try {
                  onAction!();
                } finally {
                  handle?.dismiss();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: ts.colors.onToast,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
        type: ToastType.none,
        position: PopupPosition.bottom,
        style: style,
        lifetime: lifetime,
      ),
    );
    handle = opened.handleOrNull;
  }

  static void loading(
    BuildContext context, {
    String? message,
    Future<void>? until,
  }) {
    final ts = TS.of(context);
    final style = LoadingStyle(
      backgroundColor: ts.colors.surface,
      borderRadius: ts.radius.md,
      padding: EdgeInsets.all(ts.spacing.lg),
      textStyle: ts.textStyle.content,
      indicatorColor: ts.colors.primary,
      indicatorStrokeWidth: ts.sizing.progressStroke,
    );
    final lifetime = until == null
        ? const PopupLifetime.manual()
        : PopupLifetime.until(until);
    if (message == null || message.isEmpty) {
      Pop.loading(
        LoadingConfig.indicator(
          style: style,
          lifetime: lifetime,
          barrier: PopupBarrierConfig(
            color: ts.colors.scrim,
            dismissible: false,
          ),
        ),
      );
    } else {
      Pop.loading(
        LoadingConfig.text(
          message,
          style: style,
          lifetime: lifetime,
          barrier: PopupBarrierConfig(
            color: ts.colors.scrim,
            dismissible: false,
          ),
        ),
      );
    }
  }

  static Future<void> hideLoading() => Pop.hideLoading();

  static Future<T> runLoading<T>(
    BuildContext context, {
    String message = '加载中',
    required Future<T> task,
  }) async {
    final settled = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    AppPop.loading(context, message: message, until: settled);
    return task;
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String content = '',
    String confirmText = '确定',
    String cancelText = '取消',
    bool danger = false,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) async {
    final ts = TS.of(context);
    final themes = InheritedTheme.capture(from: context, to: null);
    final radius = BorderRadius.circular(ts.radius.xl);
    final popup = Pop.confirm(
      ConfirmConfig(
        title: title,
        content: content,
        barrier: PopupBarrierConfig(color: ts.colors.scrim, dismissible: false),
        style: ConfirmStyle(
          borderRadius: radius,
          surface: _surface(context, material),
          decoration: BoxDecoration(
            color: ts.colors.surface,
            borderRadius: radius,
          ),
          titleStyle: ts.textStyle.title,
          textAlign: TextAlign.start,
          contentStyle: ts.textStyle.content,
          contentPadding: EdgeInsets.fromLTRB(
            ts.spacing.md,
            ts.spacing.md,
            ts.spacing.md,
            ts.spacing.none,
          ),
          buttonPadding: EdgeInsets.fromLTRB(
            ts.spacing.md,
            ts.spacing.none,
            ts.spacing.md,
            ts.spacing.md,
          ),
          margin: EdgeInsets.all(ts.spacing.lg),
          titleGap: ts.spacing.smPlus,
          contentButtonGap: ts.spacing.lg,
          buttonSpacing: ts.spacing.smPlus,
        ),
        confirmButton: (onTap) => themes.wrap(
          CommonButton(
            label: confirmText,
            kind: danger ? CommonButtonKind.danger : CommonButtonKind.primary,
            onPressed: onTap,
            block: true,
          ),
        ),
        cancelButton: (onTap) => themes.wrap(
          CommonButton(
            label: cancelText,
            kind: CommonButtonKind.secondary,
            onPressed: onTap,
            block: true,
          ),
        ),
      ),
    );
    final result = await popup.result;
    await popup.handleOrNull?.dismissed;
    return result ?? false;
  }

  static Future<T?> sheet<T>(
    BuildContext context, {
    String? title,
    required Widget Function(BuildContext context, AppSheetActions<T> actions)
    builder,
    bool showCloseButton = true,
    SheetSizeConfig size = const SheetSizeConfig(),
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
          titleWidget: _header(
            context,
            title ?? '',
            close: showCloseButton ? () => popup.handleOrNull?.dismiss() : null,
          ),
          showCloseButton: false,
        ),
        style: _sheetStyle(context, material),
        barrier: PopupBarrierConfig(color: ts.colors.scrim),
        animation: PopupAnimationConfig(
          type: PopupAnimationType.slideUp,
          duration: ts.motion.durationSheet,
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
  }) async {
    final ts = TS.of(context);
    final themes = InheritedTheme.capture(from: context, to: null);
    late PopupOpenResult<R> popup;
    popup = Pop.flowSheet<R>(
      FlowSheetConfig<R>(
        controller: controller,
        initialPage: initialPage,
        header: SheetHeaderConfig(
          titleWidget: themes.wrap(
            Material(
              type: MaterialType.transparency,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => _header(
                  context,
                  controller.canPop
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
        style: _sheetStyle(context, material),
        size:
            size ??
            SheetSizeConfig(
              height: SheetDimension.pixel(
                ts.sizing.controlLg * 6 + ts.spacing.lg * 2,
              ),
            ),
        drag: drag,
        animation: PopupAnimationConfig(
          type: PopupAnimationType.slideUp,
          duration: ts.motion.durationSheet,
          slideOffset: 1,
        ),
        barrier: PopupBarrierConfig(color: ts.colors.scrim),
      ),
    );
    final result = await popup.result;
    await popup.handleOrNull?.dismissed;
    return result;
  }

  static Widget _header(
    BuildContext context,
    String title, {
    Widget? start,
    VoidCallback? close,
  }) {
    final ts = TS.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ts.spacing.md,
        0,
        ts.spacing.md,
        ts.spacing.lg,
      ),
      child: SizedBox(
        height: ts.sizing.touch,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ts.sizing.touch),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: ts.textStyle.subtitle,
              ),
            ),
            if (start != null)
              Align(alignment: Alignment.centerLeft, child: start),
            if (close != null)
              Align(
                alignment: Alignment.centerRight,
                child: CommonIconButton(
                  name: CommonIconName.x,
                  label: '关闭',
                  variant: CommonIconButtonVariant.tonal,
                  onPressed: close,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<T?> dropMenu<T>(
    BuildContext context, {
    required PopupAnchorController anchor,
    required DropMenu<T> menu,
    ValueChanged<T>? onSelected,
    MenuPlacement placement = MenuPlacement.auto,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) {
    final ts = TS.of(context);
    return Pop.dropMenu<T>(
      DropMenuConfig<T>(
        anchor: anchor,
        menu: menu,
        onSelected: onSelected,
        placement: placement,
        offset: Offset(ts.spacing.none, ts.spacing.xsPlus),
        menuStyle: DropMenuStyle(
          surface: _surface(context, material),
          borderRadius: BorderRadius.circular(ts.radius.md),
          constraints: const DropMenuStyle().constraints.copyWith(
            maxHeight: ts.layout.menuMaxHeight,
          ),
          textColor: ts.colors.onSurface,
          secondaryTextColor: ts.colors.onSurfaceMuted,
          selectedColor: ts.colors.primary,
          dividerColor: ts.colors.divider,
          textStyle: ts.textStyle.content,
          secondaryTextStyle: ts.textStyle.caption,
          iconSize: ts.sizing.iconMd,
          dividerIndent: ts.spacing.md,
          dividerThickness: ts.border.widthHairline,
          itemPadding: EdgeInsets.symmetric(
            horizontal: ts.spacing.md,
            vertical: ts.spacing.smPlus,
          ),
        ),
      ),
    ).result;
  }

  static Future<T?> actionSheet<T>(
    BuildContext context, {
    String? title,
    required List<AppSheetAction<T>> actions,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) => sheet<T>(
    context,
    title: title,
    material: material,
    builder: (context, handle) {
      final ts = TS.of(context);
      return ListView.separated(
        shrinkWrap: true,
        itemCount: actions.length,
        separatorBuilder: (_, _) => Divider(color: ts.colors.divider),
        itemBuilder: (context, index) {
          final action = actions[index];
          return ListTile(
            title: Text(
              action.label,
              style: ts.textStyle.content.copyWith(
                color: action.danger ? ts.colors.error : ts.colors.onSurface,
              ),
            ),
            enabled: !action.disabled,
            onTap: () => handle.complete(action.value),
          );
        },
      );
    },
  );
}

class AppSheetAction<T> {
  const AppSheetAction({
    required this.value,
    required this.label,
    this.danger = false,
    this.disabled = false,
  });
  final T value;
  final String label;
  final bool danger;
  final bool disabled;
}

/// Business result callbacks; SDK handles stay inside the popup facade.
class AppSheetActions<T> {
  AppSheetActions(this._handle);
  final PopupHandle<T> _handle;
  Future<void> complete([T? value]) => _handle.complete(value);
  Future<void> dismiss() => _handle.dismiss();
}
