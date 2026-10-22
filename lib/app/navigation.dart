import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/state/local_value.dart';

final rootTabProvider = NotifierProvider<LocalValue<int>, int>(
  () => LocalValue(0),
);
