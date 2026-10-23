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
