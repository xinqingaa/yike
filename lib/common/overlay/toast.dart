import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import 'popup_activity.dart';

abstract final class ToastPopup {
  static void show(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    double bottomInset = 0,
    String? replacementKey,
  }) {
    assert((actionLabel == null) == (onAction == null));
    final ts = TS.of(popupHostContext());
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
    final lifetime = PopupLifetime.after(duration ?? ts.motion.durationToast);
    if (actionLabel == null) {
      Pop.toast(
        ToastConfig.text(
          message,
          type: ToastType.none,
          position: PopupPosition.bottom,
          style: style,
          lifetime: lifetime,
          behavior: PopupBehaviorConfig(
            key: replacementKey,
            conflictPolicy: PopupConflictPolicy.replaceExisting,
            backPolicy: PopupBackPolicy.ignore,
          ),
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
        behavior: PopupBehaviorConfig(
          key: replacementKey,
          conflictPolicy: PopupConflictPolicy.replaceExisting,
          backPolicy: PopupBackPolicy.ignore,
        ),
      ),
    );
    handle = opened.handleOrNull;
  }

  static Future<void> clearToasts() => Pop.dismissChannel(PopupChannel.toast);
}
