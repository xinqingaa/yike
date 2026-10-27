import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/display/glass_surface.dart';
import 'popup_activity.dart';
import 'popup_theme.dart';
import 'sheet.dart';
import 'popup_completion.dart';
import 'sheet_actions.dart';

abstract final class MenuPopup {
  static Future<T?> dropMenu<T>({
    required PopupAnchorController anchor,
    required DropMenu<T> menu,
    ValueChanged<T>? onSelected,
    MenuPlacement placement = MenuPlacement.auto,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) {
    final context = popupHostContext();
    final ts = TS.of(context);
    return Pop.dropMenu<T>(
      DropMenuConfig<T>(
        anchor: anchor,
        menu: menu,
        onSelected: onSelected,
        placement: placement,
        offset: Offset(ts.spacing.none, ts.spacing.xsPlus),
        menuStyle: DropMenuStyle(
          surface: PopupTheme.surface(context, material),
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

  static Future<T?> actionSheet<T>({
    String? title,
    required List<AppSheetAction<T>> actions,
    CommonSurfaceMaterial material = CommonSurfaceMaterial.solid,
  }) {
    final completion = PopupCompletion<T>();
    return SheetPopup.show<T>(
      title: title,
      material: material,
      attach: completion.attach,
      child: Builder(
        builder: (context) {
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
                    color: action.danger
                        ? ts.colors.error
                        : ts.colors.onSurface,
                  ),
                ),
                enabled: !action.disabled,
                onTap: () => completion.complete(action.value),
              );
            },
          );
        },
      ),
    );
  }
}
