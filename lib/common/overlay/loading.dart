import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';

abstract final class LoadingPopup {
  static void show(
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
    show(context, message: message, until: settled);
    return task;
  }
}
