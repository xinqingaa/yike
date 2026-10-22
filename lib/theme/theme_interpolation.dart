import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'app_tokens.dart';
import 'app_text_styles.dart';

/// Continuous values stay in target token space during AnimatedTheme frames.
abstract final class ThemeInterpolation {
  static AppSpacing spacing(AppSpacing a, AppSpacing b, double t) => AppSpacing(
    none: lerpDouble(a.none, b.none, t)!,
    xxs: lerpDouble(a.xxs, b.xxs, t)!,
    xs: lerpDouble(a.xs, b.xs, t)!,
    xsPlus: lerpDouble(a.xsPlus, b.xsPlus, t)!,
    sm: lerpDouble(a.sm, b.sm, t)!,
    smPlus: lerpDouble(a.smPlus, b.smPlus, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
    lgPlus: lerpDouble(a.lgPlus, b.lgPlus, t)!,
    xxl: lerpDouble(a.xxl, b.xxl, t)!,
    xxxl: lerpDouble(a.xxxl, b.xxxl, t)!,
    toastGap: lerpDouble(a.toastGap, b.toastGap, t)!,
  );
  static AppSizing sizing(AppSizing a, AppSizing b, double t) => AppSizing(
    controlSm: lerpDouble(a.controlSm, b.controlSm, t)!,
    controlMd: lerpDouble(a.controlMd, b.controlMd, t)!,
    controlLg: lerpDouble(a.controlLg, b.controlLg, t)!,
    iconSm: lerpDouble(a.iconSm, b.iconSm, t)!,
    iconCompact: lerpDouble(a.iconCompact, b.iconCompact, t)!,
    iconMd: lerpDouble(a.iconMd, b.iconMd, t)!,
    iconLg: lerpDouble(a.iconLg, b.iconLg, t)!,
    avatarSm: lerpDouble(a.avatarSm, b.avatarSm, t)!,
    avatarMd: lerpDouble(a.avatarMd, b.avatarMd, t)!,
    avatarLg: lerpDouble(a.avatarLg, b.avatarLg, t)!,
    touch: lerpDouble(a.touch, b.touch, t)!,
    menuItem: lerpDouble(a.menuItem, b.menuItem, t)!,
    tab: lerpDouble(a.tab, b.tab, t)!,
    bottomNavigation: lerpDouble(a.bottomNavigation, b.bottomNavigation, t)!,
    caret: lerpDouble(a.caret, b.caret, t)!,
    indicatorThickness: lerpDouble(
      a.indicatorThickness,
      b.indicatorThickness,
      t,
    )!,
    progressStroke: lerpDouble(a.progressStroke, b.progressStroke, t)!,
    progressTrack: lerpDouble(a.progressTrack, b.progressTrack, t)!,
    refreshActionHeight: lerpDouble(
      a.refreshActionHeight,
      b.refreshActionHeight,
      t,
    )!,
    refreshActionMinWidth: lerpDouble(
      a.refreshActionMinWidth,
      b.refreshActionMinWidth,
      t,
    )!,
    stepDot: lerpDouble(a.stepDot, b.stepDot, t)!,
    textareaRows: (t < .5 ? a.textareaRows : b.textareaRows),
    panelMedium: lerpDouble(a.panelMedium, b.panelMedium, t)!,
    panelLarge: lerpDouble(a.panelLarge, b.panelLarge, t)!,
    ring: lerpDouble(a.ring, b.ring, t)!,
    brand: lerpDouble(a.brand, b.brand, t)!,
    plot: lerpDouble(a.plot, b.plot, t)!,
    actionMinInline: lerpDouble(a.actionMinInline, b.actionMinInline, t)!,
    badgeLabelSize: lerpDouble(a.badgeLabelSize, b.badgeLabelSize, t)!,
  );
  static AppRadius radius(AppRadius a, AppRadius b, double t) => AppRadius(
    none: lerpDouble(a.none, b.none, t)!,
    xs: lerpDouble(a.xs, b.xs, t)!,
    sm: lerpDouble(a.sm, b.sm, t)!,
    md: lerpDouble(a.md, b.md, t)!,
    lg: lerpDouble(a.lg, b.lg, t)!,
    xl: lerpDouble(a.xl, b.xl, t)!,
    full: lerpDouble(a.full, b.full, t)!,
  );
  static AppLayoutTokens layouttokens(
    AppLayoutTokens a,
    AppLayoutTokens b,
    double t,
  ) => AppLayoutTokens(
    dialogMaxWidth: lerpDouble(a.dialogMaxWidth, b.dialogMaxWidth, t)!,
    formMaxWidth: lerpDouble(a.formMaxWidth, b.formMaxWidth, t)!,
    fill: lerpDouble(a.fill, b.fill, t)!,
    flexFill: lerpDouble(a.flexFill, b.flexFill, t)!,
    flexGrow: lerpDouble(a.flexGrow, b.flexGrow, t)!,
    focusInset: lerpDouble(a.focusInset, b.focusInset, t)!,
    gestureAxisLock: lerpDouble(a.gestureAxisLock, b.gestureAxisLock, t)!,
    gestureDragLimit: lerpDouble(a.gestureDragLimit, b.gestureDragLimit, t)!,
    gestureSwipeThreshold: lerpDouble(
      a.gestureSwipeThreshold,
      b.gestureSwipeThreshold,
      t,
    )!,
    half: lerpDouble(a.half, b.half, t)!,
    halfNegative: lerpDouble(a.halfNegative, b.halfNegative, t)!,
    insetSmNegative: lerpDouble(a.insetSmNegative, b.insetSmNegative, t)!,
    insetXsNegative: lerpDouble(a.insetXsNegative, b.insetXsNegative, t)!,
    loadMoreRootMargin: EdgeInsets.lerp(
      a.loadMoreRootMargin,
      b.loadMoreRootMargin,
      t,
    )!,
    menuMaxHeight: lerpDouble(a.menuMaxHeight, b.menuMaxHeight, t)!,
    pullRefreshMaxDistance: lerpDouble(
      a.pullRefreshMaxDistance,
      b.pullRefreshMaxDistance,
      t,
    )!,
    pullRefreshThreshold: lerpDouble(
      a.pullRefreshThreshold,
      b.pullRefreshThreshold,
      t,
    )!,
    sheetMaxHeight: lerpDouble(a.sheetMaxHeight, b.sheetMaxHeight, t)!,
    translateFullNegative: lerpDouble(
      a.translateFullNegative,
      b.translateFullNegative,
      t,
    )!,
    viewportHeight: lerpDouble(a.viewportHeight, b.viewportHeight, t)!,
    chartMinHeight: lerpDouble(a.chartMinHeight, b.chartMinHeight, t)!,
    chartPlotHeight: lerpDouble(a.chartPlotHeight, b.chartPlotHeight, t)!,
    previewViewportHeight: lerpDouble(
      a.previewViewportHeight,
      b.previewViewportHeight,
      t,
    )!,
  );
  static AppOpacity opacity(AppOpacity a, AppOpacity b, double t) => AppOpacity(
    isDark: t < .5 ? a.isDark : b.isDark,
    disabled: lerpDouble(a.disabled, b.disabled, t)!,
    hover: lerpDouble(a.hover, b.hover, t)!,
    pressed: lerpDouble(a.pressed, b.pressed, t)!,
    translucentValue: lerpDouble(a.translucent, b.translucent, t)!,
    dataLow: lerpDouble(a.dataLow, b.dataLow, t)!,
    dataMedium: lerpDouble(a.dataMedium, b.dataMedium, t)!,
    dataHigh: lerpDouble(a.dataHigh, b.dataHigh, t)!,
  );
  static AppElevation elevation(AppElevation a, AppElevation b, double t) =>
      AppElevation(
        isDark: t < .5 ? a.isDark : b.isDark,
        floatingShadow: BoxShadow.lerp(a.floating, b.floating, t),
        glassShadow: BoxShadow.lerp(a.glass, b.glass, t),
        menuShadow: BoxShadow.lerp(a.menu, b.menu, t),
        overlayShadow: BoxShadow.lerp(a.overlay, b.overlay, t),
        surfaceShadows: BoxShadow.lerpList(a.surface, b.surface, t),
      );
  static AppEffectTokens effect(
    AppEffectTokens a,
    AppEffectTokens b,
    double t,
  ) => AppEffectTokens(
    glassBackdropBlur: lerpDouble(a.glassBackdropBlur, b.glassBackdropBlur, t)!,
    artworkShadow: BoxShadow.lerpList(a.artworkShadow, b.artworkShadow, t)!,
  );
  static AppTypography typography(AppTypography a, AppTypography b, double t) =>
      AppTypography(
        display: TextStyle.lerp(a.display, b.display, t)!,
        headline: TextStyle.lerp(a.headline, b.headline, t)!,
        titleLg: TextStyle.lerp(a.titleLg, b.titleLg, t)!,
        title: TextStyle.lerp(a.title, b.title, t)!,
        titleSm: TextStyle.lerp(a.titleSm, b.titleSm, t)!,
        subtitle: TextStyle.lerp(a.subtitle, b.subtitle, t)!,
        bodyLg: TextStyle.lerp(a.bodyLg, b.bodyLg, t)!,
        content: TextStyle.lerp(a.content, b.content, t)!,
        bodySm: TextStyle.lerp(a.bodySm, b.bodySm, t)!,
        label: TextStyle.lerp(a.label, b.label, t)!,
        caption: TextStyle.lerp(a.caption, b.caption, t)!,
        captionStrong: TextStyle.lerp(a.captionStrong, b.captionStrong, t)!,
        micro: TextStyle.lerp(a.micro, b.micro, t)!,
        trackingDisplay: AppLetterSpacing.pixels(
          lerpDouble(
            a.trackingDisplay.resolve(a.display),
            b.trackingDisplay.resolve(b.display),
            t,
          )!,
        ),
        trackingHeading: AppLetterSpacing.pixels(
          lerpDouble(
            a.trackingHeading.resolve(a.title),
            b.trackingHeading.resolve(b.title),
            t,
          )!,
        ),
        trackingLabel: AppLetterSpacing.pixels(
          lerpDouble(
            a.trackingLabel.resolve(a.label),
            b.trackingLabel.resolve(b.label),
            t,
          )!,
        ),
        trackingCaption: AppLetterSpacing.pixels(
          lerpDouble(
            a.trackingCaption.resolve(a.caption),
            b.trackingCaption.resolve(b.caption),
            t,
          )!,
        ),
      );
}
