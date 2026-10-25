import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/state/local_value.dart';

final timerStatusInsetProvider = NotifierProvider<LocalValue<double>, double>(
  () => LocalValue(0),
);
