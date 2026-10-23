import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

/// Application-owned handle; the SDK handle stays inside the popup boundary.
class AppStatusPopup {
  AppStatusPopup._(this._handle);
  final PopupHandle<void> _handle;
  bool get active => _handle.isActive;
  Future<void> get dismissed => _handle.dismissed;
  Future<void> dismiss() => _handle.dismiss();
  void suspend(bool value) {
    if (value) {
      _handle.pause();
    } else {
      _handle.resume();
    }
  }

  static AppStatusPopup? show(BuildContext context, Widget content) {
    final opened = Pop.custom<void>(
      CustomPopupConfig<void>(
        behavior: const PopupBehaviorConfig(
          key: 'yike-unsaved',
          conflictPolicy: PopupConflictPolicy.rejectNew,
          routePolicy: PopupRoutePolicy.persist,
          backPolicy: PopupBackPolicy.ignore,
        ),
        barrier: const PopupBarrierConfig.hidden(),
        position: PopupPosition.top,
        // The content owns its animation so changing reduced-motion preference
        // takes effect even during entry/exit; the persistent host never reopens.
        animationConfig: const PopupAnimationConfig(
          type: PopupAnimationType.none,
        ),
        builder: (_, _) => content,
      ),
    );
    final handle = opened.handleOrNull;
    return handle == null ? null : AppStatusPopup._(handle);
  }
}
