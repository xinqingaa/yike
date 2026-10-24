import 'package:flutter/material.dart';

/// Stable timer-type mapping across all dial themes, with a dark appearance.
abstract final class AppChartColors {
  static const light = [
    Color(0xFFC8735E),
    Color(0xFF4C8E88),
    Color(0xFF6A7FB8),
  ];
  static const dark = [Color(0xFFE8A08A), Color(0xFF87C2BA), Color(0xFFA5B7E4)];
  static List<Color> resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
