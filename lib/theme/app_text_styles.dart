import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Resolves CSS-relative tracking against the font actually used by the style.
@immutable
class AppLetterSpacing {
  const AppLetterSpacing.pixels(this.value) : relative = false;
  const AppLetterSpacing.em(this.value) : relative = true;
  final double value;
  final bool relative;
  double resolve(TextStyle style) => relative ? value * style.fontSize! : value;
}

@immutable
class AppTypography {
  const AppTypography({
    this.display = const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 40,
      height: 1.15,
    ),
    this.headline = const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 1.2,
    ),
    this.titleLg = const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 24,
      height: 1.25,
    ),
    this.title = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20,
      height: 1.3,
    ),
    this.titleSm = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.35,
    ),
    this.subtitle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 1.4,
    ),
    this.bodyLg = const TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 16,
      height: 1.55,
    ),
    this.content = const TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.5,
    ),
    this.bodySm = const TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 13,
      height: 1.5,
    ),
    this.label = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.4,
    ),
    this.caption = const TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 1.4,
    ),
    this.captionStrong = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.4,
    ),
    this.micro = const TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 11.52,
      height: 1.2,
    ),
    this.numericDisplay = const TextStyle(
      fontSize: 40,
      height: 1.15,
      fontWeight: FontWeight.w700,
    ),
    this.numericTitle = const TextStyle(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    this.numericContent = const TextStyle(fontSize: 14, height: 1.5),
    this.trackingDisplay = const AppLetterSpacing.pixels(0),
    this.trackingHeading = const AppLetterSpacing.pixels(0),
    this.trackingLabel = const AppLetterSpacing.pixels(0),
    this.trackingCaption = const AppLetterSpacing.pixels(0),
  });
  final TextStyle display;
  final TextStyle headline;
  final TextStyle titleLg;
  final TextStyle title;
  final TextStyle titleSm;
  final TextStyle subtitle;
  final TextStyle bodyLg;
  final TextStyle content;
  final TextStyle bodySm;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle captionStrong;
  final TextStyle micro;
  final TextStyle numericDisplay, numericTitle, numericContent;
  final AppLetterSpacing trackingDisplay;
  final AppLetterSpacing trackingHeading;
  final AppLetterSpacing trackingLabel;
  final AppLetterSpacing trackingCaption;
}

class AppTextStyles {
  const AppTextStyles({required this.colors, required this.typography});
  final AppColors colors;
  final AppTypography typography;
  TextStyle get display => typography.display.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingDisplay.resolve(typography.display),
  );
  TextStyle get headline => typography.headline.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingHeading.resolve(typography.headline),
  );
  TextStyle get titleLg => typography.titleLg.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingHeading.resolve(typography.titleLg),
  );
  TextStyle get title => typography.title.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingHeading.resolve(typography.title),
  );
  TextStyle get titleSm => typography.titleSm.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingHeading.resolve(typography.titleSm),
  );
  TextStyle get subtitle => typography.subtitle.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingHeading.resolve(typography.subtitle),
  );
  TextStyle get bodyLg =>
      typography.bodyLg.copyWith(color: colors.onSurface, letterSpacing: 0);
  TextStyle get content =>
      typography.content.copyWith(color: colors.onSurface, letterSpacing: 0);
  TextStyle get bodySm =>
      typography.bodySm.copyWith(color: colors.onSurface, letterSpacing: 0);
  TextStyle get label => typography.label.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingLabel.resolve(typography.label),
  );
  TextStyle get caption => typography.caption.copyWith(
    color: colors.onSurfaceMuted,
    letterSpacing: typography.trackingCaption.resolve(typography.caption),
  );
  TextStyle get captionStrong => typography.captionStrong.copyWith(
    color: colors.onSurface,
    letterSpacing: typography.trackingCaption.resolve(typography.captionStrong),
  );
  TextStyle get micro => typography.micro.copyWith(
    color: colors.onSurfaceMuted,
    letterSpacing: typography.trackingCaption.resolve(typography.micro),
  );
  TextStyle get numericDisplay => typography.numericDisplay.copyWith(
    color: colors.onSurface,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  TextStyle get numericTitle => typography.numericTitle.copyWith(
    color: colors.onSurface,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  TextStyle get numericContent => typography.numericContent.copyWith(
    color: colors.onSurface,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  AppLetterSpacing get trackingDisplay => typography.trackingDisplay;
  AppLetterSpacing get trackingHeading => typography.trackingHeading;
  AppLetterSpacing get trackingLabel => typography.trackingLabel;
  AppLetterSpacing get trackingCaption => typography.trackingCaption;
}
