import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/state/local_value.dart';

final rootNavigationEpochProvider = NotifierProvider<LocalValue<int>, int>(
  () => LocalValue(0),
);

class RootTabs extends LocalValue<int> {
  RootTabs() : super(0);
  @override
  void set(int value) {
    if (value == state) return;
    if (value != 1) {
      ref.read(habitReminderTargetsProvider.notifier).set(const {});
    }
    ref.read(rootNavigationEpochProvider.notifier).update((n) => n + 1);
    super.set(value);
  }

  @override
  void update(int Function(int) change) => set(change(state));
}

final rootTabProvider = NotifierProvider<RootTabs, int>(RootTabs.new);

final habitReminderTargetsProvider =
    NotifierProvider<LocalValue<Set<String>>, Set<String>>(
      () => LocalValue(const {}),
    );
