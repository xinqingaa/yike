import 'package:flutter/material.dart';
import 'package:unified_popups/unified_popups.dart';

import '../../theme/ts.dart';
import 'popup_activity.dart';

abstract final class CustomPopup {
  static Future<T?> show<T>({
    required Widget child,
    void Function(PopupHandle<T>)? attach,
  }) async {
    final context = popupHostContext();
    final ts = TS.of(context);
    final popup = Pop.custom<T>(
      CustomPopupConfig<T>(
        barrier: PopupBarrierConfig(color: ts.colors.scrim),
        // A shallow translation keeps the glass outside an opacity buffer.
        animationConfig: PopupAnimationConfig(
          type: PopupAnimationType.slideUp,
          slideOffset: .035,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : ts.motion.durationSheet,
          curve: ts.motion.easingGentle,
        ),
        // Read the live host theme in the child's build, including theme choice.
        builder: (_, _) => child,
      ),
    );
    final handle = popup.handleOrNull;
    if (handle != null) attach?.call(handle);
    final result = await popup.result;
    await handle?.dismissed;
    return result;
  }
}
