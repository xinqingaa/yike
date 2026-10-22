import 'package:flutter/material.dart';

/// 对齐 pbwork `color.*` token。
class AppColors {
  const AppColors({
    required this.background,
    required this.surface,
    required this.primary,
    required this.navigationActive,
    required this.sectionTabActive,
    required this.secondaryTabActive,
    required this.secondaryIndicator,
    required this.primarySoft,
    required this.onPrimary,
    required this.action,
    required this.actionSoft,
    required this.onAction,
    required this.secondary,
    required this.secondarySoft,
    required this.border,
    required this.error,
    required this.errorSoft,
    required this.info,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.surfaceVariant,
    required this.surfaceRaised,
    required this.surfaceRecessed,
    required this.surfaceSelected,
    required this.toast,
    required this.onToast,
    required this.onBackground,
    required this.onSecondary,
    required this.outline,
    required this.divider,
    required this.disabled,
    required this.scrim,
    required this.onError,
    required this.onSuccess,
    required this.onWarning,
    required this.onInfo,
    required this.glassTint,
    required this.glassClear,
    required this.glassEdge,
    required this.primaryTabsSelectionTint,
    required this.tabbarSelectionTint,
    required this.buttonGlassPrimaryTint,
    required this.iconButtonGlassPrimaryTint,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color navigationActive;
  final Color sectionTabActive;
  final Color secondaryTabActive;
  final Color secondaryIndicator;
  final Color primarySoft;
  final Color onPrimary;
  final Color action;
  final Color actionSoft;
  final Color onAction;
  final Color secondary;
  final Color secondarySoft;
  final Color border;
  final Color error;
  final Color errorSoft;
  final Color info;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color surfaceVariant;
  final Color surfaceRaised;
  final Color surfaceRecessed;
  final Color surfaceSelected;
  final Color toast;
  final Color onToast;
  final Color onBackground;
  final Color onSecondary;
  final Color outline;
  final Color divider;
  final Color disabled;
  final Color scrim;
  final Color onError;
  final Color onSuccess;
  final Color onWarning;
  final Color onInfo;
  final Color glassTint;
  final Color glassClear;
  final Color glassEdge;
  final Color primaryTabsSelectionTint;
  final Color tabbarSelectionTint;
  final Color buttonGlassPrimaryTint;
  final Color iconButtonGlassPrimaryTint;

  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? primary,
    Color? navigationActive,
    Color? sectionTabActive,
    Color? secondaryTabActive,
    Color? secondaryIndicator,
    Color? primarySoft,
    Color? onPrimary,
    Color? action,
    Color? actionSoft,
    Color? onAction,
    Color? secondary,
    Color? secondarySoft,
    Color? border,
    Color? error,
    Color? errorSoft,
    Color? info,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? surfaceVariant,
    Color? surfaceRaised,
    Color? surfaceRecessed,
    Color? surfaceSelected,
    Color? toast,
    Color? onToast,
    Color? onBackground,
    Color? onSecondary,
    Color? outline,
    Color? divider,
    Color? disabled,
    Color? scrim,
    Color? onError,
    Color? onSuccess,
    Color? onWarning,
    Color? onInfo,
    Color? glassTint,
    Color? glassClear,
    Color? glassEdge,
    Color? primaryTabsSelectionTint,
    Color? tabbarSelectionTint,
    Color? buttonGlassPrimaryTint,
    Color? iconButtonGlassPrimaryTint,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    primary: primary ?? this.primary,
    navigationActive: navigationActive ?? this.navigationActive,
    sectionTabActive: sectionTabActive ?? this.sectionTabActive,
    secondaryTabActive: secondaryTabActive ?? this.secondaryTabActive,
    secondaryIndicator: secondaryIndicator ?? this.secondaryIndicator,
    primarySoft: primarySoft ?? this.primarySoft,
    onPrimary: onPrimary ?? this.onPrimary,
    action: action ?? this.action,
    actionSoft: actionSoft ?? this.actionSoft,
    onAction: onAction ?? this.onAction,
    secondary: secondary ?? this.secondary,
    secondarySoft: secondarySoft ?? this.secondarySoft,
    border: border ?? this.border,
    error: error ?? this.error,
    errorSoft: errorSoft ?? this.errorSoft,
    info: info ?? this.info,
    success: success ?? this.success,
    successSoft: successSoft ?? this.successSoft,
    warning: warning ?? this.warning,
    warningSoft: warningSoft ?? this.warningSoft,
    onSurface: onSurface ?? this.onSurface,
    onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
    surfaceVariant: surfaceVariant ?? this.surfaceVariant,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceRecessed: surfaceRecessed ?? this.surfaceRecessed,
    surfaceSelected: surfaceSelected ?? this.surfaceSelected,
    toast: toast ?? this.toast,
    onToast: onToast ?? this.onToast,
    onBackground: onBackground ?? this.onBackground,
    onSecondary: onSecondary ?? this.onSecondary,
    outline: outline ?? this.outline,
    divider: divider ?? this.divider,
    disabled: disabled ?? this.disabled,
    scrim: scrim ?? this.scrim,
    onError: onError ?? this.onError,
    onSuccess: onSuccess ?? this.onSuccess,
    onWarning: onWarning ?? this.onWarning,
    onInfo: onInfo ?? this.onInfo,
    glassTint: glassTint ?? this.glassTint,
    glassClear: glassClear ?? this.glassClear,
    glassEdge: glassEdge ?? this.glassEdge,
    primaryTabsSelectionTint:
        primaryTabsSelectionTint ?? this.primaryTabsSelectionTint,
    tabbarSelectionTint: tabbarSelectionTint ?? this.tabbarSelectionTint,
    buttonGlassPrimaryTint:
        buttonGlassPrimaryTint ?? this.buttonGlassPrimaryTint,
    iconButtonGlassPrimaryTint:
        iconButtonGlassPrimaryTint ?? this.iconButtonGlassPrimaryTint,
  );

  AppColors lerp(AppColors other, double t) => AppColors(
    background: Color.lerp(background, other.background, t)!,
    surface: Color.lerp(surface, other.surface, t)!,
    primary: Color.lerp(primary, other.primary, t)!,
    navigationActive: Color.lerp(navigationActive, other.navigationActive, t)!,
    sectionTabActive: Color.lerp(sectionTabActive, other.sectionTabActive, t)!,
    secondaryTabActive: Color.lerp(
      secondaryTabActive,
      other.secondaryTabActive,
      t,
    )!,
    secondaryIndicator: Color.lerp(
      secondaryIndicator,
      other.secondaryIndicator,
      t,
    )!,
    primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
    onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    action: Color.lerp(action, other.action, t)!,
    actionSoft: Color.lerp(actionSoft, other.actionSoft, t)!,
    onAction: Color.lerp(onAction, other.onAction, t)!,
    secondary: Color.lerp(secondary, other.secondary, t)!,
    secondarySoft: Color.lerp(secondarySoft, other.secondarySoft, t)!,
    border: Color.lerp(border, other.border, t)!,
    error: Color.lerp(error, other.error, t)!,
    errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
    info: Color.lerp(info, other.info, t)!,
    success: Color.lerp(success, other.success, t)!,
    successSoft: Color.lerp(successSoft, other.successSoft, t)!,
    warning: Color.lerp(warning, other.warning, t)!,
    warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
    onSurface: Color.lerp(onSurface, other.onSurface, t)!,
    onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
    surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
    surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
    surfaceRecessed: Color.lerp(surfaceRecessed, other.surfaceRecessed, t)!,
    surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
    toast: Color.lerp(toast, other.toast, t)!,
    onToast: Color.lerp(onToast, other.onToast, t)!,
    onBackground: Color.lerp(onBackground, other.onBackground, t)!,
    onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
    outline: Color.lerp(outline, other.outline, t)!,
    divider: Color.lerp(divider, other.divider, t)!,
    disabled: Color.lerp(disabled, other.disabled, t)!,
    scrim: Color.lerp(scrim, other.scrim, t)!,
    onError: Color.lerp(onError, other.onError, t)!,
    onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
    onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    glassTint: Color.lerp(glassTint, other.glassTint, t)!,
    glassClear: Color.lerp(glassClear, other.glassClear, t)!,
    glassEdge: Color.lerp(glassEdge, other.glassEdge, t)!,
    primaryTabsSelectionTint: Color.lerp(
      primaryTabsSelectionTint,
      other.primaryTabsSelectionTint,
      t,
    )!,
    tabbarSelectionTint: Color.lerp(
      tabbarSelectionTint,
      other.tabbarSelectionTint,
      t,
    )!,
    buttonGlassPrimaryTint: Color.lerp(
      buttonGlassPrimaryTint,
      other.buttonGlassPrimaryTint,
      t,
    )!,
    iconButtonGlassPrimaryTint: Color.lerp(
      iconButtonGlassPrimaryTint,
      other.iconButtonGlassPrimaryTint,
      t,
    )!,
  );
}
