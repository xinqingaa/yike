import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 对齐 pbwork `spacing.*` token（逻辑像素）。
class AppSpacing {
  const AppSpacing({
    this.none = 0,
    this.xxs = 2,
    this.xs = 4,
    this.xsPlus = 6,
    this.sm = 8,
    this.smPlus = 12,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.lgPlus = 40,
    this.xxl = 48,
    this.xxxl = 64,
    this.toastGap = 10,
  });

  /// Producer `toast.gap` 的 10px 垂直内边距；不并入 4/8 刻度。

  final double none;
  final double xxs;
  final double xs;
  final double xsPlus;
  final double sm;
  final double smPlus;
  final double md;
  final double lg;
  final double xl;
  final double lgPlus;
  final double xxl;
  final double xxxl;
  final double toastGap;
}

/// 对齐 pbwork `sizing.*` token。
class AppSizing {
  const AppSizing({
    this.controlSm = 32,
    this.controlMd = 40,
    this.controlLg = 48,
    this.iconSm = 16,
    this.iconCompact = 18,
    this.iconMd = 20,
    this.iconLg = 24,
    this.avatarSm = 28,
    this.avatarMd = 40,
    this.avatarLg = 56,
    this.touch = 44,
    this.menuItem = 48,
    this.tab = 44,
    this.bottomNavigation = 64,
    this.caret = 5,
    this.indicatorThickness = 3,
    this.progressStroke = 2,
    this.progressTrack = 6,
    this.refreshActionHeight = 36,
    this.refreshActionMinWidth = 96,
    this.stepDot = 6,
    this.textareaRows = 3,
    this.panelMedium = 0.5,
    this.panelLarge = 0.86,
    this.ring = 112,
    this.brand = 72,
    this.plot = 160,
    this.actionMinInline = 0,
    this.badgeLabelSize = 10,
  });

  /// 面板高度档位按视口比例消费（Producer 的 50dvh / 86dvh）。

  final double controlSm;
  final double controlMd;
  final double controlLg;
  final double iconSm;
  final double iconCompact;
  final double iconMd;
  final double iconLg;
  final double avatarSm;
  final double avatarMd;
  final double avatarLg;
  final double touch;
  final double menuItem;
  final double tab;
  final double bottomNavigation;
  final double caret;
  final double indicatorThickness;
  final double progressStroke;
  final double progressTrack;
  final double refreshActionHeight;
  final double refreshActionMinWidth;
  final double stepDot;
  final int textareaRows;
  final double panelMedium;
  final double panelLarge;
  final double ring;
  final double brand;
  final double plot;
  final double actionMinInline;
  final double badgeLabelSize;
}

/// 对齐 pbwork `radius.*` token。
class AppRadius {
  const AppRadius({
    this.none = 0,
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.full = 999,
  });

  final double none;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;
}

/// 对齐 pbwork `opacity.*` token。
class AppOpacity {
  const AppOpacity({
    required this.isDark,
    this.disabled = 0.38,
    this.hover = 0.08,
    this.pressed = 0.14,
    this.translucentValue,
    this.dataLow = 0.3,
    this.dataMedium = 0.65,
    this.dataHigh = 1,
  });
  final bool isDark;
  final double disabled, hover, pressed, dataLow, dataMedium, dataHigh;
  final double? translucentValue;
  double get translucent => translucentValue ?? (isDark ? 0.8 : 0.76);
  double get muted => 0.62;
  double get overlay => 0.6;
  double get hidden => 0;
  double get visible => 1;
}

/// 对齐 pbwork `motion.*` token。
class AppMotion {
  const AppMotion({
    this.durationFast = const Duration(milliseconds: 120),
    this.durationInstant = Duration.zero,
    this.durationNormal = const Duration(milliseconds: 200),
    this.durationSlow = const Duration(milliseconds: 320),
    this.durationSheet = const Duration(milliseconds: 220),
    this.durationTabViewport = const Duration(milliseconds: 240),
    this.durationToast = const Duration(milliseconds: 4000),
    this.durationClickSuppression = const Duration(milliseconds: 450),
    this.easingGentle = Curves.ease,
    this.easingStandard = const Cubic(0.2, 0, 0, 1),
    this.easingEmphasized = const Cubic(0.2, 0.8, 0.2, 1),
    this.rotateHalfTurn = 0.5,
    this.scalePressed = 0.98,
    this.scalePressedStrong = 0.96,
  });

  final Duration durationFast;
  final Duration durationInstant;
  final Duration durationNormal;
  final Duration durationSlow;
  final Duration durationSheet;
  final Duration durationTabViewport;
  final Duration durationToast;
  final Duration durationClickSuppression;
  final Curve easingGentle;
  final Curve easingStandard;
  final Curve easingEmphasized;
  final double rotateHalfTurn;
  final double scalePressed;
  final double scalePressedStrong;
}

/// 对齐 pbwork `elevation.*`。
///
/// 常规 surface 使用 Material elevation 数字；`elevation.glass` 保留主题相关的
/// 单层低对比阴影，以供静态玻璃 Decoration 直接绘制。
class AppElevation {
  const AppElevation({
    required this.isDark,
    this.floatingShadow,
    this.glassShadow,
    this.menuShadow,
    this.overlayShadow,
    this.surfaceShadows,
  });
  final BoxShadow? floatingShadow, glassShadow, menuShadow, overlayShadow;
  final List<BoxShadow>? surfaceShadows;

  final bool isDark;

  double get none => 0;
  double get card => 1;
  BoxShadow get floating =>
      floatingShadow ??
      BoxShadow(
        color: isDark
            ? const Color.fromRGBO(0, 0, 0, 0.28)
            : const Color.fromRGBO(15, 23, 42, 0.08),
        blurRadius: 18,
        offset: const Offset(0, 6),
      );
  BoxShadow get glass =>
      glassShadow ??
      BoxShadow(
        color: isDark ? const Color(0x40000000) : const Color(0x141D3040),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );
  double get raised => 4;
  double get level1 => 1;
  double get level2 => 3;
  double get level3 => 6;
  double get level4 => 8;
  double get level5 => 12;

  BoxShadow get menu =>
      menuShadow ??
      BoxShadow(
        color: isDark
            ? const Color.fromRGBO(0, 0, 0, 0.45)
            : const Color.fromRGBO(15, 23, 42, 0.14),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );
  BoxShadow get overlay =>
      overlayShadow ??
      BoxShadow(
        color: isDark
            ? const Color.fromRGBO(0, 0, 0, 0.58)
            : const Color.fromRGBO(15, 23, 42, 0.2),
        blurRadius: 48,
        offset: const Offset(0, 22),
      );
  List<BoxShadow> get surface =>
      surfaceShadows ??
      (isDark
          ? const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.35),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.28),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ]
          : const [
              BoxShadow(
                color: Color.fromRGBO(15, 23, 42, 0.08),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color.fromRGBO(15, 23, 42, 0.06),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ]);
}

/// 对齐组件实际消费的 `border.*` token。
class AppBorderTokens {
  const AppBorderTokens({required this.colors, this.scale = 1});

  final double scale;

  final AppColors colors;

  BorderSide get defaultBorder =>
      BorderSide(color: colors.border, width: scale);
  BorderSide get strong => BorderSide(color: colors.outline, width: 2 * scale);
  BorderSide get focus => BorderSide(color: colors.primary, width: 2 * scale);
  BorderSide get hairline => BorderSide(color: colors.divider, width: scale);
  BorderSide get glass => BorderSide(color: colors.glassEdge, width: scale);
  double get widthHairline => scale;
  double get widthStrong => 2 * scale;
  double get accentWidth => 4 * scale;
}

/// 对齐跨栈布局语义；值是 Flutter 逻辑像素、比例或 Insets。
class AppLayoutTokens {
  const AppLayoutTokens({
    this.dialogMaxWidth = 320,
    this.formMaxWidth = 480,
    this.fill = 1,
    this.flexFill = 1,
    this.flexGrow = 1,
    this.focusInset = -4,
    this.gestureAxisLock = 8,
    this.gestureDragLimit = 72,
    this.gestureSwipeThreshold = 44,
    this.half = 0.5,
    this.halfNegative = -0.5,
    this.insetSmNegative = -8,
    this.insetXsNegative = -4,
    this.loadMoreRootMargin = const EdgeInsets.only(bottom: 120),
    this.menuMaxHeight = 304,
    this.pullRefreshMaxDistance = 112,
    this.pullRefreshThreshold = 64,
    this.sheetMaxHeight = 560,
    this.translateFullNegative = -1,
    this.viewportHeight = 1,
    this.chartMinHeight = 154,
    this.chartPlotHeight = 124,
    this.previewViewportHeight = 128,
  });

  final double dialogMaxWidth;
  final double formMaxWidth;
  final double fill;
  final double flexFill;
  final double flexGrow;
  final double focusInset;
  final double gestureAxisLock;
  final double gestureDragLimit;
  final double gestureSwipeThreshold;
  final double half;
  final double halfNegative;
  final double insetSmNegative;
  final double insetXsNegative;
  final EdgeInsets loadMoreRootMargin;
  final double menuMaxHeight;
  final double pullRefreshMaxDistance;
  final double pullRefreshThreshold;
  final double sheetMaxHeight;
  final double translateFullNegative;
  final double viewportHeight;
  final double chartMinHeight;
  final double chartPlotHeight;
  final double previewViewportHeight;
}

class AppLayerTokens {
  const AppLayerTokens({this.base = 0, this.content = 1});

  final double base;
  final double content;
}

class AppEffectTokens {
  const AppEffectTokens({
    this.glassBackdropBlur = 12,
    this.artworkShadow = const [],
  });

  /// Flutter 近似 CSS `blur(12px) saturate(1.06)` 的 blur sigma。

  /// Producer 的基础包没有图形投影；保留空列表作为显式“无效果”。

  final double glassBackdropBlur;
  final List<BoxShadow> artworkShadow;
}

/// Producer `asset.*` 在当前 target 尚未绑定真实文件；空值表示显式未提供。
class AppAssets {
  const AppAssets({
    this.brandMark,
    this.brandWordmark,
    this.emptyIllustration,
    this.launchImage,
  });

  final String? brandMark;
  final String? brandWordmark;
  final String? emptyIllustration;
  final String? launchImage;
}
