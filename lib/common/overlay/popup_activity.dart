import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final popupActivityProvider = NotifierProvider<PopupActivity, int>(
  PopupActivity.new,
);

/// Counts application modals through their actual visual dismissal, including
/// nested sheets. Toasts and persistent status affordances are not modals.
class PopupActivity extends Notifier<int> {
  @override
  int build() => 0;

  Future<T> track<T>(Future<T> Function() open) async {
    state++;
    try {
      return await open();
    } finally {
      if (ref.mounted) state--;
    }
  }

  static Future<T> modal<T>(BuildContext context, Future<T> Function() open) =>
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(popupActivityProvider.notifier).track(open);
}
