import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unified_popups/liquid_glass.dart';

import '../common/widgets/navigation/screen_transition.dart';
import '../storage/providers.dart';
import '../storage/app_prefs.dart';
import '../storage/preference_writer.dart';
import 'app_colors.dart';
import 'app_chart_colors.dart';
import 'app_text_styles.dart';
import 'app_tokens.dart';
import 'app_metrics.dart';
import 'theme_pack.dart';
import 'theme_interpolation.dart';

import 'dart:ui' show lerpDouble;

export 'theme_pack.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    String? stored;
    try {
      stored = ref.watch(appPrefsProvider).read(AppPrefs.themeMode);
    } catch (_) {
      stored = null;
    }
    return switch (stored) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  void setMode(ThemeMode mode) {
    ref
        .read(preferenceWriterProvider.notifier)
        .save(AppPrefs.themeMode, mode.name);
    state = mode;
  }

  void toggle() {
    setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// 当前亮度（对齐 pbwork light/dark 主题），经 [AppPrefs] 持久化。
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
  dependencies: [appPrefsProvider, preferenceWriterProvider],
);

final themePacksProvider = Provider<List<AppThemePack>>(
  (ref) => generatedThemePacks,
  dependencies: const [],
);

class ThemePackNotifier extends Notifier<AppThemePack> {
  @override
  AppThemePack build() {
    final packs = ref.watch(themePacksProvider);
    if (packs.isEmpty ||
        packs.any((pack) => pack.id.trim().isEmpty) ||
        packs.map((pack) => pack.id).toSet().length != packs.length) {
      throw StateError('Theme packs must have nonempty, unique identities.');
    }
    String? stored;
    try {
      stored = ref.watch(appPrefsProvider).read(AppPrefs.themePack);
    } catch (_) {
      stored = null;
    }
    return packs.firstWhere(
      (pack) => pack.id == stored,
      orElse: () => packs.firstWhere(
        (pack) => pack.id == 'yike/mechanical',
        orElse: () => packs.first,
      ),
    );
  }

  void select(String id) {
    final pack = ref
        .read(themePacksProvider)
        .firstWhere((pack) => pack.id == id);
    ref.read(preferenceWriterProvider.notifier).save(AppPrefs.themePack, id);
    state = pack;
  }
}

final themePackProvider = NotifierProvider<ThemePackNotifier, AppThemePack>(
  ThemePackNotifier.new,
  dependencies: [
    appPrefsProvider,
    themePacksProvider,
    preferenceWriterProvider,
  ],
);

/// ThemeExtension owned by the nearest Material Theme, never a global singleton.
class TS extends ThemeExtension<TS> {
  /// Opaque heatmap steps, lightest to strongest: outside, archived, empty.
  Color _heatmapInk(double light, double dark) => Color.alphaBlend(
    colors.onSurface.withValues(
      alpha: brightness == Brightness.dark ? dark : light,
    ),
    colors.background,
  );

  /// Before creation, future days, and week-alignment padding.
  Color get heatmapOutside => _heatmapInk(.12, .14);

  /// Archived days that were not completed.
  Color get heatmapArchived => _heatmapInk(.17, .20);

  /// In-range days with no completion or no focus time.
  Color get heatmapEmpty => _heatmapInk(.22, .28);

  List<Color> get chartTypeColors => AppChartColors.resolve(brightness);
  TS({
    required this.brightness,
    this.pack = AppThemePack.base,
    this.metrics = const AppMetrics.identity(),
    AppColors? colors,
    this.transitionFrom,
    this.transitionTo,
    this.transitionProgress = 1,
  }) : colors = colors ?? pack.colorsFor(brightness);

  final TS? transitionFrom, transitionTo;
  final double transitionProgress;
  bool get _blending => transitionFrom != null && transitionTo != null;

  /// Stable artwork endpoints, composited with the same progress as token colors.
  Map<TS, double> get artworkThemes {
    if (!_blending) return {this: 1};
    final weights = <TS, double>{};
    void add(Map<TS, double> endpoints, double factor) {
      for (final entry in endpoints.entries) {
        weights.update(
          entry.key,
          (value) => value + entry.value * factor,
          ifAbsent: () => entry.value * factor,
        );
      }
    }

    // Rapidly reversing to an existing endpoint must add its contributions.
    add(transitionFrom!.artworkThemes, 1 - transitionProgress);
    add(transitionTo!.artworkThemes, transitionProgress);
    return weights;
  }

  double get artworkAspectRatio => _blending
      ? lerpDouble(
          transitionFrom!.artworkAspectRatio,
          transitionTo!.artworkAspectRatio,
          transitionProgress,
        )!
      : pack.id.endsWith('water')
      ? 368 / 236
      : pack.id.endsWith('sundial')
      ? 404 / 316
      : 1;

  TS forPack(AppThemePack value) => _blending
      ? transitionFrom!
            .forPack(value)
            .lerp(transitionTo!.forPack(value), transitionProgress)
      : TS(brightness: brightness, pack: value, metrics: metrics);

  final Brightness brightness;
  final AppThemePack pack;
  final AppMetrics metrics;
  final AppColors colors;
  bool get isDark => brightness == Brightness.dark;
  late final AppTextStyles textStyle = AppTextStyles(
    colors: colors,
    typography: _typography,
  );
  late final AppTypography _typography = _blending
      ? ThemeInterpolation.typography(
          transitionFrom!._typography,
          transitionTo!._typography,
          transitionProgress,
        )
      : metrics.typography(pack.typography);
  late final AppSpacing spacing = _blending
      ? ThemeInterpolation.spacing(
          transitionFrom!.spacing,
          transitionTo!.spacing,
          transitionProgress,
        )
      : metrics.spacing(pack.spacing);
  late final AppSizing sizing = _blending
      ? ThemeInterpolation.sizing(
          transitionFrom!.sizing,
          transitionTo!.sizing,
          transitionProgress,
        )
      : metrics.sizing(pack.sizing);
  late final AppRadius radius = _blending
      ? ThemeInterpolation.radius(
          transitionFrom!.radius,
          transitionTo!.radius,
          transitionProgress,
        )
      : metrics.radii(pack.radius);
  late final AppOpacity opacity = _blending
      ? ThemeInterpolation.opacity(
          transitionFrom!.opacity,
          transitionTo!.opacity,
          transitionProgress,
        )
      : isDark
      ? pack.darkOpacity
      : pack.lightOpacity;
  AppMotion get motion => pack.motion;
  late final AppElevation elevation = _blending
      ? ThemeInterpolation.elevation(
          transitionFrom!.elevation,
          transitionTo!.elevation,
          transitionProgress,
        )
      : metrics.elevation(isDark ? pack.darkElevation : pack.lightElevation);
  late final AppBorderTokens border = AppBorderTokens(
    colors: colors,
    scale: metrics.radius,
  );
  late final AppLayoutTokens layout = _blending
      ? ThemeInterpolation.layouttokens(
          transitionFrom!.layout,
          transitionTo!.layout,
          transitionProgress,
        )
      : metrics.layout(pack.layout);
  AppLayerTokens get layer => pack.layer;
  late final AppEffectTokens effect = _blending
      ? ThemeInterpolation.effect(
          transitionFrom!.effect,
          transitionTo!.effect,
          transitionProgress,
        )
      : metrics.effect(isDark ? pack.darkEffect ?? pack.effect : pack.effect);
  AppAssets get assets => isDark ? pack.darkAssets ?? pack.assets : pack.assets;

  static TS of(BuildContext context) {
    final tokens = Theme.of(context).extension<TS>();
    if (tokens == null) throw StateError('Install TS in ThemeData.extensions.');
    return tokens;
  }

  @override
  TS copyWith({
    Brightness? brightness,
    AppThemePack? pack,
    AppColors? colors,
  }) => TS(
    brightness: brightness ?? this.brightness,
    metrics: metrics,
    pack: pack ?? this.pack,
    colors: colors ?? (pack == null && brightness == null ? this.colors : null),
  );

  @override
  TS lerp(covariant TS? other, double t) {
    if (other == null || t <= 0) return this;
    if (t >= 1) return other;
    final target = t < 0.5 ? this : other;
    return TS(
      brightness: target.brightness,
      metrics: target.metrics,
      pack: target.pack,
      colors: colors.lerp(other.colors, t),
      transitionFrom: this,
      transitionTo: other,
      transitionProgress: t,
    );
  }

  /// Shared material for popup surfaces and in-page glass controls.
  LiquidGlassStyle glassStyle({bool clear = false, Color? tint}) {
    final base = tint ?? (clear ? colors.glassClear : colors.glassTint);
    return LiquidGlassStyle(
      backgroundColor: base.withValues(alpha: base.a * .92),
      borderColor: colors.glassEdge,
      topHighlightColor: colors.glassEdge,
      pressHighlightColor: colors.primary.withValues(alpha: opacity.pressed),
      shadowColor: elevation.glass.color,
      blurSigma: effect.glassBackdropBlur * 1.4,
      outlineWidth: border.widthHairline,
      topStrokeWidth: border.widthStrong,
      shadowBlurRadius: elevation.glass.blurRadius,
      shadowOffset: elevation.glass.offset,
      pressColorDuration: motion.durationFast,
      pressScaleDuration: motion.durationNormal,
      pressScale: motion.scalePressed,
      pressCurve: motion.easingStandard,
    );
  }

  /// System icons follow the effective surface, including transparent AppBars.
  SystemUiOverlayStyle get systemOverlayStyle =>
      overlayStyleFor(colors.surface);

  SystemUiOverlayStyle overlayStyleFor(Color surface) {
    final darkSurface =
        ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: darkSurface ? Brightness.light : Brightness.dark,
      statusBarBrightness: darkSurface ? Brightness.dark : Brightness.light,
    );
  }

  ThemeData toThemeData() {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      error: colors.error,
      onError: colors.onError,
      surface: colors.surface,
      onSurface: colors.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      extensions: [this],
      brightness: brightness,
      colorScheme: scheme,
      pageTransitionsTheme: PbPageTransitions.theme(),
      scaffoldBackgroundColor: colors.background,
      dividerColor: colors.divider,
      iconTheme: IconThemeData(size: sizing.iconMd, color: colors.onSurface),
      textTheme: TextTheme(
        displayLarge: textStyle.display,
        headlineMedium: textStyle.headline,
        titleLarge: textStyle.title,
        titleMedium: textStyle.subtitle,
        titleSmall: textStyle.titleSm,
        bodyLarge: textStyle.bodyLg,
        bodyMedium: textStyle.content,
        bodySmall: textStyle.bodySm,
        labelLarge: textStyle.label,
        labelMedium: textStyle.captionStrong,
        labelSmall: textStyle.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        systemOverlayStyle: systemOverlayStyle,
        elevation: elevation.none,
        centerTitle: true,
        titleTextStyle: textStyle.title,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.secondarySoft,
        selectedColor: colors.primarySoft,
        labelStyle: textStyle.captionStrong,
        side: border.defaultBorder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.full),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.smPlus,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: border.defaultBorder,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: border.defaultBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.md),
          borderSide: border.focus,
        ),
        labelStyle: textStyle.label.copyWith(color: colors.onSurfaceMuted),
        hintStyle: textStyle.content.copyWith(color: colors.onSurfaceMuted),
      ),
    );
  }
}
