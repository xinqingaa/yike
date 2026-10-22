import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_tokens.dart';
import 'app_text_styles.dart';

/// Immutable viewport conversion, captured after ScreenUtilInit has measured.
/// Theme packs remain in design units; consumers receive converted tokens once.
class AppMetrics {
  const AppMetrics.identity()
    : width = 1,
      height = 1,
      radius = 1,
      font = 1,
      compactText = false;
  AppMetrics.fromScreenUtil()
    : width = 1.w.clamp(0.85, 1.25),
      height = 1.h.clamp(0.85, 1.25),
      radius = 1.r.clamp(0.85, 1.15),
      font = 1.sp.clamp(0.85, 1),
      compactText = true;

  static const designSize = Size(390, 844);
  final double width, height, radius, font;
  final bool compactText;

  BoxShadow shadow(BoxShadow value) => value.copyWith(
    blurRadius: value.blurRadius * radius,
    spreadRadius: value.spreadRadius * radius,
    offset: value.offset * radius,
  );
  TextStyle text(TextStyle value, {double? ceiling}) => value.copyWith(
    fontSize:
        (compactText && ceiling != null && value.fontSize! > ceiling
            ? ceiling
            : value.fontSize!) *
        font,
    letterSpacing: value.letterSpacing == null
        ? null
        : value.letterSpacing! * font,
  );
  AppLetterSpacing tracking(AppLetterSpacing value) =>
      value.relative ? value : AppLetterSpacing.pixels(value.value * font);

  AppSpacing spacing(AppSpacing value) => AppSpacing(
    none: value.none * radius,
    xxs: value.xxs * radius,
    xs: value.xs * radius,
    xsPlus: value.xsPlus * radius,
    sm: value.sm * radius,
    smPlus: value.smPlus * radius,
    md: value.md * radius,
    lg: value.lg * radius,
    xl: value.xl * radius,
    lgPlus: value.lgPlus * radius,
    xxl: value.xxl * radius,
    xxxl: value.xxxl * radius,
    toastGap: value.toastGap * radius,
  );

  AppSizing sizing(AppSizing value) => AppSizing(
    controlSm: value.controlSm * height,
    controlMd: value.controlMd * height,
    controlLg: value.controlLg * height,
    iconSm: value.iconSm * radius,
    iconCompact: value.iconCompact * radius,
    iconMd: value.iconMd * radius,
    iconLg: value.iconLg * radius,
    avatarSm: value.avatarSm * radius,
    avatarMd: value.avatarMd * radius,
    avatarLg: value.avatarLg * radius,
    touch: (value.touch * radius).clamp(44, double.infinity),
    menuItem: (value.menuItem * height).clamp(44, double.infinity),
    tab: value.tab * height,
    bottomNavigation: value.bottomNavigation * height,
    caret: value.caret * radius,
    indicatorThickness: value.indicatorThickness * radius,
    progressStroke: value.progressStroke * radius,
    progressTrack: value.progressTrack * radius,
    refreshActionHeight: value.refreshActionHeight * height,
    refreshActionMinWidth: value.refreshActionMinWidth * width,
    stepDot: value.stepDot * radius,
    textareaRows: value.textareaRows,
    panelMedium: value.panelMedium,
    panelLarge: value.panelLarge,
    ring: value.ring * radius,
    brand: value.brand * radius,
    plot: value.plot * radius,
    actionMinInline: value.actionMinInline * width,
    badgeLabelSize: value.badgeLabelSize * font,
  );

  AppRadius radii(AppRadius value) => AppRadius(
    none: value.none * radius,
    xs: value.xs * radius,
    sm: value.sm * radius,
    md: value.md * radius,
    lg: value.lg * radius,
    xl: value.xl * radius,
    full: value.full * radius,
  );

  AppLayoutTokens layout(AppLayoutTokens value) => AppLayoutTokens(
    dialogMaxWidth: value.dialogMaxWidth * width,
    formMaxWidth: value.formMaxWidth * width,
    fill: value.fill,
    flexFill: value.flexFill,
    flexGrow: value.flexGrow,
    focusInset: value.focusInset * radius,
    gestureAxisLock: value.gestureAxisLock * radius,
    gestureDragLimit: value.gestureDragLimit * radius,
    gestureSwipeThreshold: value.gestureSwipeThreshold * radius,
    half: value.half,
    halfNegative: value.halfNegative,
    insetSmNegative: value.insetSmNegative * radius,
    insetXsNegative: value.insetXsNegative * radius,
    loadMoreRootMargin: value.loadMoreRootMargin * height,
    menuMaxHeight: value.menuMaxHeight * height,
    pullRefreshMaxDistance: value.pullRefreshMaxDistance * height,
    pullRefreshThreshold: value.pullRefreshThreshold * height,
    sheetMaxHeight: value.sheetMaxHeight * height,
    translateFullNegative: value.translateFullNegative,
    viewportHeight: value.viewportHeight,
    chartMinHeight: value.chartMinHeight * height,
    chartPlotHeight: value.chartPlotHeight * height,
    previewViewportHeight: value.previewViewportHeight * height,
  );

  AppElevation elevation(AppElevation value) => AppElevation(
    isDark: value.isDark,
    floatingShadow: shadow(value.floating),
    glassShadow: shadow(value.glass),
    menuShadow: shadow(value.menu),
    overlayShadow: shadow(value.overlay),
    surfaceShadows: value.surface.map(shadow).toList(),
  );
  AppEffectTokens effect(AppEffectTokens value) => AppEffectTokens(
    glassBackdropBlur: value.glassBackdropBlur * radius,
    artworkShadow: value.artworkShadow.map(shadow).toList(),
  );
  AppTypography typography(AppTypography value) => AppTypography(
    display: text(value.display, ceiling: 36),
    headline: text(value.headline, ceiling: 24),
    titleLg: text(value.titleLg, ceiling: 22),
    title: text(value.title, ceiling: 18),
    titleSm: text(value.titleSm, ceiling: 16),
    subtitle: text(value.subtitle, ceiling: 15),
    bodyLg: text(value.bodyLg, ceiling: 15),
    content: text(value.content, ceiling: 14),
    bodySm: text(value.bodySm, ceiling: 13),
    label: text(value.label, ceiling: 14),
    caption: text(value.caption, ceiling: 12),
    captionStrong: text(value.captionStrong, ceiling: 12),
    micro: text(value.micro),
    numericDisplay: text(value.numericDisplay),
    numericTitle: text(value.numericTitle),
    numericContent: text(value.numericContent),
    trackingDisplay: tracking(value.trackingDisplay),
    trackingHeading: tracking(value.trackingHeading),
    trackingLabel: tracking(value.trackingLabel),
    trackingCaption: tracking(value.trackingCaption),
  );
}

/// Shared bootstrap for ready, preparing and retry screens.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.builder});
  final Widget Function(BuildContext, AppMetrics) builder;

  @override
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: AppMetrics.designSize,
    minTextAdapt: true,
    splitScreenMode: true,
    fontSizeResolver: FontSizeResolvers.radius,
    builder: (context, _) => builder(context, AppMetrics.fromScreenUtil()),
  );
}
