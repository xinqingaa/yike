import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import '../widgets/action/button.dart';
import '../widgets/display/glass_surface.dart';
import 'popup_theme.dart';

abstract final class ConfirmPopup {
  static Future<bool> show(
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
          surface: PopupTheme.surface(context, material),
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
}
