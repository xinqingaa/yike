import 'package:unified_popups/unified_popups.dart';

class AppSheetAction<T> {
  const AppSheetAction({
    required this.value,
    required this.label,
    this.danger = false,
    this.disabled = false,
  });
  final T value;
  final String label;
  final bool danger;
  final bool disabled;
}

/// Business result callbacks; SDK handles stay inside the popup facade.
class AppSheetActions<T> {
  AppSheetActions(this._handle);
  final PopupHandle<T> _handle;
  Future<void> complete([T? value]) => _handle.complete(value);
  Future<void> dismiss() => _handle.dismiss();
}
