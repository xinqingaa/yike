import 'package:flutter/material.dart';

import '../../../theme/ts.dart';
import '../action/button.dart';
import '../action/icon.dart';
import '../action/icon_button.dart';
import '../display/glass_surface.dart';

enum CommonAppBarSurface { theme, solid, glass, transparent }

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommonAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.glassProgress,
    this.dense = false,
    this.elevated = false,
    this.showBack = false,
    this.backLabel = '返回',
    this.onBack,
    this.showAction = false,
    this.actionIcon = CommonIconName.more,
    this.actionLabel = '更多操作',
    this.actionText,
    this.onAction,
    this.background = CommonAppBarSurface.theme,
  });

  final String title;
  final Widget? titleWidget;
  final double? glassProgress;
  final bool dense;
  final bool elevated;
  final bool showBack;
  final String backLabel;
  final VoidCallback? onBack;
  final bool showAction;
  final CommonIconName actionIcon;
  final String actionLabel;
  final String? actionText;
  final VoidCallback? onAction;
  final CommonAppBarSurface background;

  @override
  Size get preferredSize => Size.fromHeight(dense ? 64 : 72);

  @override
  Widget build(BuildContext context) {
    final ts = TS.of(context);
    final glass =
        background == CommonAppBarSurface.glass ||
        (background == CommonAppBarSurface.theme &&
            ts.pack.surfaceTreatment == AppSurfaceTreatment.glass);
    final transparent = glass || background == CommonAppBarSurface.transparent;
    return AppBar(
      automaticallyImplyLeading: false,
      clipBehavior: Clip.none,
      leadingWidth: ts.spacing.lg + ts.sizing.touch + ts.spacing.sm,
      actionsPadding: EdgeInsetsDirectional.only(end: ts.spacing.lg),
      forceMaterialTransparency: transparent,
      flexibleSpace: glass || glassProgress != null
          ? CommonGlassSurface(
              reveal: glassProgress ?? 1,
              clear: glassProgress != null,
              edges: glassProgress != null
                  ? CommonGlassEdges.none
                  : CommonGlassEdges.bottom,
              child: SizedBox.expand(),
            )
          : null,
      toolbarHeight: preferredSize.height,
      title:
          titleWidget ??
          (title.trim().isEmpty
              ? null
              : Text(
                  title,
                  style: ts.textStyle.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
      centerTitle: true,
      elevation: elevated ? ts.elevation.card : ts.elevation.none,
      backgroundColor: transparent ? Colors.transparent : ts.colors.surface,
      foregroundColor: ts.colors.onSurface,
      systemOverlayStyle: ts.overlayStyleFor(
        glass
            ? Color.alphaBlend(ts.colors.glassTint, ts.colors.background)
            : transparent
            ? ts.colors.background
            : ts.colors.surface,
      ),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: ts.elevation.none,
      shape: transparent ? null : Border(bottom: ts.border.hairline),
      leading: showBack
          ? Padding(
              padding: EdgeInsetsDirectional.only(
                start: ts.spacing.lg,
                end: ts.spacing.sm,
              ),
              child: CommonIconButton(
                material: CommonSurfaceMaterial.glass,
                name: CommonIconName.chevronRight,
                label: backLabel,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                quarterTurns: 2,
                variant: CommonIconButtonVariant.text,
              ),
            )
          : null,
      actions: showAction
          ? [
              if (actionText != null)
                CommonButton(
                  label: actionText!,
                  kind: CommonButtonKind.quiet,
                  onPressed: onAction,
                )
              else
                CommonIconButton(
                  name: actionIcon,
                  label: actionLabel,
                  onPressed: onAction,
                  size: CommonControlSize.sm,
                  variant: CommonIconButtonVariant.text,
                ),
            ]
          : null,
    );
  }
}
