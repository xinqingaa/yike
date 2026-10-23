import 'package:flutter_test/flutter_test.dart';
import 'package:yike/common/motion/rolling_digits.dart';

Finder dialDigits(String value) => find.byWidgetPredicate(
  (widget) =>
      widget is RollingDigits && !widget.inverse && widget.value == value,
  description: 'visible dial readout $value',
);
