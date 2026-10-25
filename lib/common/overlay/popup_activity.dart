import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../router/navigator_key.dart';

final popupActivityProvider = NotifierProvider<PopupActivity, int>(
  PopupActivity.new,
);

/// Navigator context under the app theme. Popup APIs do not take a call-site context.
BuildContext popupHostContext() {
  final context = appNavigatorKey.currentContext;
  if (context == null) {
    throw StateError('弹层需要已挂载的导航器。');
  }
  return context;
}

/// Counts application modals through their actual visual dismissal, including
/// nested sheets. Toasts and persistent status affordances are not modals.
class PopupActivity extends Notifier<int> {
  @override
  int build() => 0;

  int timerPanelCount = 0;

  Future<T> track<T>(
    Future<T> Function() open, {
    bool timerPanel = false,
  }) async {
    if (timerPanel) timerPanelCount++;
    state++;
    try {
      return await open();
    } finally {
      if (timerPanel) timerPanelCount--;
      if (ref.mounted) state--;
    }
  }

  static Future<T> modal<T>(
    Future<T> Function() open, {
    bool timerPanel = false,
  }) => ProviderScope.containerOf(
    popupHostContext(),
    listen: false,
  ).read(popupActivityProvider.notifier).track(open, timerPanel: timerPanel);
}
