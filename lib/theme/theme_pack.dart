import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_text_styles.dart';

part 'generated_theme_packs.dart';

enum AppSurfaceTreatment { solid, outlined, glass }

/// One typed source for a target theme package, including its light/dark modes.
@immutable
class AppThemePack {
  const AppThemePack({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
    this.darkAssets,
    this.darkEffect,
    this.surfaceTreatment = AppSurfaceTreatment.solid,
    this.spacing = const AppSpacing(),
    this.sizing = const AppSizing(),
    this.radius = const AppRadius(),
    this.motion = const AppMotion(),
    this.layout = const AppLayoutTokens(),
    this.layer = const AppLayerTokens(),
    this.effect = const AppEffectTokens(),
    this.assets = const AppAssets(),
    this.typography = const AppTypography(),
    this.lightOpacity = const AppOpacity(isDark: false),
    this.darkOpacity = const AppOpacity(isDark: true),
    this.lightElevation = const AppElevation(isDark: false),
    this.darkElevation = const AppElevation(isDark: true),
  });

  final String id;
  final String label;
  final AppSurfaceTreatment surfaceTreatment;
  final AppColors light;
  final AppColors dark;
  final AppSpacing spacing;
  final AppSizing sizing;
  final AppRadius radius;
  final AppMotion motion;
  final AppLayoutTokens layout;
  final AppLayerTokens layer;
  final AppEffectTokens effect;
  final AppAssets assets;
  final AppAssets? darkAssets;
  final AppEffectTokens? darkEffect;
  final AppTypography typography;
  final AppOpacity lightOpacity;
  final AppOpacity darkOpacity;
  final AppElevation lightElevation;
  final AppElevation darkElevation;

  AppColors colorsFor(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static const base = generatedBaseThemePack;
}
