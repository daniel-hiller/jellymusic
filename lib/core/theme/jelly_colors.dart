import 'package:flutter/material.dart';

/// The app's colour palette, carried on [ThemeData] as a [ThemeExtension] so it
/// can change at runtime when the user picks a different theme.
///
/// Every widget reads colours through `context.colors` (see the extension at
/// the bottom of this file) instead of a static palette, so a theme switch
/// repaints the whole tree. Each named theme provides one [JellyColors]
/// instance — see `app_themes.dart`.
@immutable
class JellyColors extends ThemeExtension<JellyColors> {
  const JellyColors({
    required this.background,
    required this.navSurface,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHigher,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentAlt,
    required this.accentBright,
    required this.onAccent,
    required this.ring,
    required this.error,
    required this.headerGradientTop,
  });

  // Base surfaces, layered from the ground up.
  final Color background;

  /// Nav rail / bottom-nav panel — a surface set apart from [background].
  final Color navSurface;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHigher;

  // Text ramp, most to least prominent.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Accent + two derived tints.
  final Color accent;
  final Color accentAlt;
  final Color accentBright;

  /// Foreground on top of a filled accent surface (e.g. the play button).
  final Color onAccent;

  /// Hairline elevation / borders.
  final Color ring;

  /// Feedback / destructive.
  final Color error;

  /// Top stop of the fallback header gradient (bottom is [background]).
  final Color headerGradientTop;

  /// Header gradient shown when no cover colour is available.
  List<Color> get defaultHeaderGradient => [headerGradientTop, background];

  @override
  JellyColors copyWith({
    Color? background,
    Color? navSurface,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHigher,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentAlt,
    Color? accentBright,
    Color? onAccent,
    Color? ring,
    Color? error,
    Color? headerGradientTop,
  }) {
    return JellyColors(
      background: background ?? this.background,
      navSurface: navSurface ?? this.navSurface,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHigher: surfaceHigher ?? this.surfaceHigher,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentAlt: accentAlt ?? this.accentAlt,
      accentBright: accentBright ?? this.accentBright,
      onAccent: onAccent ?? this.onAccent,
      ring: ring ?? this.ring,
      error: error ?? this.error,
      headerGradientTop: headerGradientTop ?? this.headerGradientTop,
    );
  }

  @override
  JellyColors lerp(ThemeExtension<JellyColors>? other, double t) {
    if (other is! JellyColors) return this;
    return JellyColors(
      background: Color.lerp(background, other.background, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHigher: Color.lerp(surfaceHigher, other.surfaceHigher, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      accentBright: Color.lerp(accentBright, other.accentBright, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      error: Color.lerp(error, other.error, t)!,
      headerGradientTop: Color.lerp(headerGradientTop, other.headerGradientTop, t)!,
    );
  }
}

/// `context.colors.accent` — the theme-aware replacement for the old static
/// `AppColors`. Reads the [JellyColors] extension off the ambient theme.
extension JellyColorsContext on BuildContext {
  JellyColors get colors => Theme.of(this).extension<JellyColors>()!;
}
