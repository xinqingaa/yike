import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import 'popup_activity.dart';

abstract final class LoadingPopup {
  static Future<void> show({String? message, Future<void>? until}) async {
    final ts = TS.of(popupHostContext());
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
    late PopupOpenResult<void> popup;
    if (message == null || message.isEmpty) {
      popup = Pop.loading(
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
      popup = Pop.loading(
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
    await popup.handleOrNull?.dismissed;
  }

  static Future<void> hideLoading() => Pop.hideLoading();

  static Future<T> runLoading<T>({
    String message = '加载中',
    required Future<T> task,
  }) async {
    final settled = task.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    PopupActivity.modal(() => show(message: message, until: settled));
    return task;
  }
}
