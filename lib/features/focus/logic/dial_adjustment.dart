import 'dart:math' as math;

import '../models/focus_view.dart';

/// Pure time mapping. Positions may overshoot; committed targets never do.
abstract final class DialAdjustment {
  static double angleDelta(double previous, double next) {
    var delta = next - previous;
    while (delta > math.pi) {
      delta -= math.pi * 2;
    }
    while (delta <= -math.pi) {
      delta += math.pi * 2;
    }
    return delta;
  }

  static double damp(double value, int maximum, int scale) {
    final edge = value.clamp(1, maximum).toDouble();
    final distance = value - edge;
    return edge + distance / (1 + distance.abs() / (scale / 12));
  }

  static int snap(double value, int maximum, {bool slow = false}) {
    if (slow) {
      final five = (value / 300).round() * 300;
      if (five >= 300 &&
          five <= maximum &&
          five <= maxFocusSeconds &&
          (five - value).abs() <= 60) {
        return five;
      }
    }
    return value.round().clamp(1, maximum);
  }

  static bool crossedMinute(double before, double after) {
    if (after > before) return after ~/ 60 > before ~/ 60;
    return (after / 60).ceil() < (before / 60).ceil();
  }
}
