import 'package:unified_popups/unified_popups.dart';

/// Keeps SDK handles inside the popup facade while a prebuilt child can close.
final class PopupCompletion<T> {
  PopupHandle<T>? _handle;

  void attach(PopupHandle<T> handle) => _handle = handle;

  Future<void> complete([T? value]) =>
      _handle?.complete(value) ?? Future<void>.value();

  Future<void> dismiss() => _handle?.dismiss() ?? Future<void>.value();
}
