import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unified_popups/liquid_glass.dart';

import '../common/widgets/navigation/screen_transition.dart';
import '../storage/providers.dart';
import '../storage/app_prefs.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_tokens.dart';
import 'app_metrics.dart';
import 'theme_pack.dart';

export 'theme_pack.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(appPrefsProvider).readThemeMode();
    return stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  void setMode(ThemeMode mode) {
    ref
        .read(appPrefsProvider)
        .writeThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
    state = mode;
  }

  void toggle() {
    setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// 当前亮度（对齐 pbwork light/dark 主题），经 [AppPrefs] 持久化。
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
  dependencies: [appPrefsProvider],
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
    final stored = ref
        .watch(appPrefsProvider)
        .readString(AppPrefs.themePackKey);
    return packs.firstWhere(
      (pack) => pack.id == stored,
      orElse: () => packs.first,
    );
  }

  void select(String id) {
    final pack = ref
        .read(themePacksProvider)
        .firstWhere((pack) => pack.id == id);
    ref.read(appPrefsProvider).writeString(AppPrefs.themePackKey, id);
    state = pack;
  }
}

final themePackProvider = NotifierProvider<ThemePackNotifier, AppThemePack>(
  ThemePackNotifier.new,
  dependencies: [appPrefsProvider, themePacksProvider],
);

/// ThemeExtension owned by the nearest Material Theme, never a global singleton.
class TS extends ThemeExtension<TS> {
  TS({
    required this.brightness,
    this.pack = AppThemePack.base,
    this.metrics = const AppMetrics.identity(),
    AppColors? colors,
  }) : colors = colors ?? pack.colorsFor(brightness);

  final Brightness brightness;
  final AppThemePack pack;
  final AppMetrics metrics;
  final AppColors colors;
  bool get isDark => brightness == Brightness.dark;
  late final AppTextStyles textStyle = AppTextStyles(
    colors: colors,
    typography: metrics.typography(pack.typography),
  );
  late final AppSpacing spacing = metrics.spacing(pack.spacing);
  late final AppSizing sizing = metrics.sizing(pack.sizing);
  late final AppRadius radius = metrics.radii(pack.radius);
  AppOpacity get opacity => isDark ? pack.darkOpacity : pack.lightOpacity;
  AppMotion get motion => pack.motion;
  late final AppElevation elevation = metrics.elevation(
    isDark ? pack.darkElevation : pack.lightElevation,
  );
  late final AppBorderTokens border = AppBorderTokens(
    colors: colors,
    scale: metrics.radius,
  );
  late final AppLayoutTokens layout = metrics.layout(pack.layout);
  AppLayerTokens get layer => pack.layer;
  late final AppEffectTokens effect = metrics.effect(
    isDark ? pack.darkEffect ?? pack.effect : pack.effect,
  );
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
    if (other == null) return this;
    final target = t < 0.5 ? this : other;
    return TS(
      brightness: target.brightness,
      metrics: target.metrics,
      pack: target.pack,
      colors: colors.lerp(other.colors, t),
    );
  }

  LiquidGlassStyle glassStyle({bool clear = false, Color? tint}) =>
      LiquidGlassStyle(
        backgroundColor: tint ?? (clear ? colors.glassClear : colors.glassTint),
        borderColor: colors.glassEdge,
        topHighlightColor: colors.glassEdge,
        pressHighlightColor: colors.primary.withValues(alpha: opacity.pressed),
        shadowColor: elevation.glass.color,
        blurSigma: effect.glassBackdropBlur,
        outlineWidth: border.widthHairline,
        topStrokeWidth: border.widthStrong,
        shadowBlurRadius: elevation.glass.blurRadius,
        shadowOffset: elevation.glass.offset,
        pressColorDuration: motion.durationFast,
        pressScaleDuration: motion.durationNormal,
        pressScale: motion.scalePressed,
        pressCurve: motion.easingStandard,
      );

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
