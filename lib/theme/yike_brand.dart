import 'package:flutter/material.dart';

/// Flutter-owned brand resources derived from the selected root logo.png.
abstract final class YikeBrand {
  static String markFor(Brightness brightness) => brightness == Brightness.dark
      ? 'asset/yike/brand/mark-dark.png'
      : 'asset/yike/brand/mark.png';
}
