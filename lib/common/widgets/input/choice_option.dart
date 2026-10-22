/// Target-side value/label pair shared by finite-choice inputs.
class CommonChoiceOption<T> {
  const CommonChoiceOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}
