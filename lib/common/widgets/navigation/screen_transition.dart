import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 对齐 pbwork `screen-transition`：栈级页面转场，不拥有路由或手势。
///
/// Flutter 用 [PageTransitionsTheme] 承接，不提供包住页面的容器，也不暴露
/// `screenKey` / `navigation`。默认全部平台使用 iOS 侧滑。
enum PbPageTransitionMode { ios, android }

abstract final class PbPageTransitions {
  static const PageTransitionsBuilder ios = CupertinoPageTransitionsBuilder();
  static const PageTransitionsBuilder android = ZoomPageTransitionsBuilder();

  static PageTransitionsTheme theme({
    PbPageTransitionMode mode = PbPageTransitionMode.ios,
  }) {
    final builder = mode == PbPageTransitionMode.android ? android : ios;
    return PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values) platform: builder,
      },
    );
  }
}
