// CupertinoPageTransitionsBuilder lives in the cupertino library; we keep it
// for the Apple platforms while overriding the desktop transitions below.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'jelly_colors.dart';

/// The selectable themes. Each carries a [JellyColors] palette and a
/// [Brightness]; [themeData] turns that into a full [ThemeData]. Add a theme by
/// adding an entry here — nothing else in the app hardcodes a palette.
enum JellyTheme {
  // Dark
  nocturne('Nocturne', Brightness.dark, _nocturne),
  obsidian('Obsidian', Brightness.dark, _obsidian),
  aurora('Aurora', Brightness.dark, _aurora),
  ember('Ember', Brightness.dark, _ember),
  sapphire('Sapphire', Brightness.dark, _sapphire),
  blossom('Blossom', Brightness.dark, _blossom),
  // Light
  daylight('Daylight', Brightness.light, _daylight),
  sandstone('Sandstone', Brightness.light, _sandstone),
  meadow('Meadow', Brightness.light, _meadow),
  coral('Coral', Brightness.light, _coral),
  sky('Sky', Brightness.light, _sky),
  rose('Rosé', Brightness.light, _rose);

  const JellyTheme(this.label, this.brightness, this.colors);

  /// Human-readable name shown in the picker.
  final String label;
  final Brightness brightness;
  final JellyColors colors;

  bool get isDark => brightness == Brightness.dark;

  ThemeData get themeData => AppTheme.build(colors, brightness);

  static JellyTheme byName(String? name) => values.firstWhere(
        (t) => t.name == name,
        orElse: () => nocturne,
      );
}

// ─── Palettes ────────────────────────────────────────────────────────

/// The original look: dark indigo ground, blurple accent.
const _nocturne = JellyColors(
  background: Color(0xFF161826),
  navSurface: Color(0xFF12131F),
  surface: Color(0xFF232532),
  surfaceHigh: Color(0xFF2B2E3D),
  surfaceHigher: Color(0xFF343747),
  textPrimary: Color(0xFFE9E9ED),
  textSecondary: Color(0xFFB2B6CA),
  textTertiary: Color(0xFF9397AB),
  accent: Color(0xFF9184D9),
  accentAlt: Color(0xFFA7A1DB),
  accentBright: Color(0xFFD2CEFD),
  onAccent: Color(0xFF161018),
  ring: Color(0xFF3F424D),
  error: Color(0xFFE8788A),
  headerGradientTop: Color(0xFF2A2C48),
);

/// AMOLED-friendly: true black surfaces, same blurple accent.
const _obsidian = JellyColors(
  background: Color(0xFF000000),
  navSurface: Color(0xFF0A0A0E),
  surface: Color(0xFF0C0C10),
  surfaceHigh: Color(0xFF15151B),
  surfaceHigher: Color(0xFF1F1F27),
  textPrimary: Color(0xFFE9E9ED),
  textSecondary: Color(0xFFB0B3C4),
  textTertiary: Color(0xFF8A8D9E),
  accent: Color(0xFF9184D9),
  accentAlt: Color(0xFFA7A1DB),
  accentBright: Color(0xFFD2CEFD),
  onAccent: Color(0xFF120E18),
  ring: Color(0xFF24242C),
  error: Color(0xFFE8788A),
  headerGradientTop: Color(0xFF141420),
);

/// Dark, cool teal — a fresher take on the dark theme.
const _aurora = JellyColors(
  background: Color(0xFF0F1C1A),
  navSurface: Color(0xFF0A1513),
  surface: Color(0xFF152623),
  surfaceHigh: Color(0xFF1C302C),
  surfaceHigher: Color(0xFF264039),
  textPrimary: Color(0xFFE6F0EC),
  textSecondary: Color(0xFFAEC6BE),
  textTertiary: Color(0xFF88A69D),
  accent: Color(0xFF37C8A0),
  accentAlt: Color(0xFF5AD6B4),
  accentBright: Color(0xFFA6F0DC),
  onAccent: Color(0xFF06201A),
  ring: Color(0xFF2E4A42),
  error: Color(0xFFE8788A),
  headerGradientTop: Color(0xFF143A31),
);

/// Light, indigo accent — the default light theme.
const _daylight = JellyColors(
  background: Color(0xFFF5F6FB),
  navSurface: Color(0xFFEBEDF4),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFEFF0F6),
  surfaceHigher: Color(0xFFE4E6EF),
  textPrimary: Color(0xFF1A1B24),
  textSecondary: Color(0xFF4E5162),
  textTertiary: Color(0xFF767A8C),
  accent: Color(0xFF6355C7),
  accentAlt: Color(0xFF7A6DD6),
  accentBright: Color(0xFF9E93EA),
  onAccent: Color(0xFFFFFFFF),
  ring: Color(0xFFD8DAE6),
  error: Color(0xFFC6455C),
  headerGradientTop: Color(0xFFE6E4F7),
);

/// Light, warm amber — a softer, paper-like light theme.
const _sandstone = JellyColors(
  background: Color(0xFFFAF6F1),
  navSurface: Color(0xFFF1EADF),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFF3ECE3),
  surfaceHigher: Color(0xFFE9E0D4),
  textPrimary: Color(0xFF241E17),
  textSecondary: Color(0xFF5A5147),
  textTertiary: Color(0xFF857A6C),
  accent: Color(0xFFC8794A),
  accentAlt: Color(0xFFD98F5F),
  accentBright: Color(0xFFEEB68C),
  onAccent: Color(0xFFFFFFFF),
  ring: Color(0xFFE2D8C9),
  error: Color(0xFFC6455C),
  headerGradientTop: Color(0xFFF0E4D6),
);

/// Dark, warm crimson — the fiery dark option.
const _ember = JellyColors(
  background: Color(0xFF1A1416),
  navSurface: Color(0xFF140F11),
  surface: Color(0xFF241A1D),
  surfaceHigh: Color(0xFF2E2226),
  surfaceHigher: Color(0xFF3A2B30),
  textPrimary: Color(0xFFF0E7E9),
  textSecondary: Color(0xFFC7B4B8),
  textTertiary: Color(0xFFA08D91),
  accent: Color(0xFFE5544E),
  accentAlt: Color(0xFFED6F66),
  accentBright: Color(0xFFF7A79E),
  onAccent: Color(0xFF2A0E0C),
  ring: Color(0xFF48343A),
  error: Color(0xFFF08A98),
  headerGradientTop: Color(0xFF3A1E22),
);

/// Dark, deep blue — calm and cool.
const _sapphire = JellyColors(
  background: Color(0xFF0F1420),
  navSurface: Color(0xFF0A0E18),
  surface: Color(0xFF171E2E),
  surfaceHigh: Color(0xFF1E2739),
  surfaceHigher: Color(0xFF283349),
  textPrimary: Color(0xFFE7ECF5),
  textSecondary: Color(0xFFAFBBD0),
  textTertiary: Color(0xFF8593AC),
  accent: Color(0xFF4C8DF6),
  accentAlt: Color(0xFF6BA2F8),
  accentBright: Color(0xFFA7C8FB),
  onAccent: Color(0xFF06152E),
  ring: Color(0xFF2E3B54),
  error: Color(0xFFE8788A),
  headerGradientTop: Color(0xFF16294A),
);

/// Dark, pink-magenta — bold and playful.
const _blossom = JellyColors(
  background: Color(0xFF1A1220),
  navSurface: Color(0xFF130D18),
  surface: Color(0xFF251A2E),
  surfaceHigh: Color(0xFF2F2239),
  surfaceHigher: Color(0xFF3B2C47),
  textPrimary: Color(0xFFF1E9F2),
  textSecondary: Color(0xFFC7B6CC),
  textTertiary: Color(0xFF9E8CA4),
  accent: Color(0xFFE060B0),
  accentAlt: Color(0xFFEB7BC0),
  accentBright: Color(0xFFF6ACD9),
  onAccent: Color(0xFF2A0A20),
  ring: Color(0xFF453454),
  error: Color(0xFFE8788A),
  headerGradientTop: Color(0xFF3A1E3A),
);

/// Light, teal-green — the light counterpart to Aurora.
const _meadow = JellyColors(
  background: Color(0xFFF1F7F4),
  navSurface: Color(0xFFE6EFEA),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFEBF2EE),
  surfaceHigher: Color(0xFFDDE8E2),
  textPrimary: Color(0xFF16211D),
  textSecondary: Color(0xFF465650),
  textTertiary: Color(0xFF6E7F79),
  accent: Color(0xFF12A67C),
  accentAlt: Color(0xFF2FB994),
  accentBright: Color(0xFF7FD6BC),
  onAccent: Color(0xFFFFFFFF),
  ring: Color(0xFFD2DFD9),
  error: Color(0xFFC6455C),
  headerGradientTop: Color(0xFFDCEEE6),
);

/// Light, warm coral-red — the light counterpart to Ember.
const _coral = JellyColors(
  background: Color(0xFFFCF3F1),
  navSurface: Color(0xFFF3E5E2),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFF6E9E6),
  surfaceHigher: Color(0xFFEEDAD5),
  textPrimary: Color(0xFF261A18),
  textSecondary: Color(0xFF5C4A46),
  textTertiary: Color(0xFF897672),
  accent: Color(0xFFE05248),
  accentAlt: Color(0xFFEA6E60),
  accentBright: Color(0xFFF3A79C),
  onAccent: Color(0xFFFFFFFF),
  ring: Color(0xFFE8D6D1),
  error: Color(0xFFC6455C),
  headerGradientTop: Color(0xFFF6E1DC),
);

/// Light, bright blue — clean and airy.
const _sky = JellyColors(
  background: Color(0xFFF1F5FC),
  navSurface: Color(0xFFE4EBF6),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFE9F0F9),
  surfaceHigher: Color(0xFFDAE5F2),
  textPrimary: Color(0xFF14202E),
  textSecondary: Color(0xFF445266),
  textTertiary: Color(0xFF6C7C90),
  accent: Color(0xFF2E82E0),
  accentAlt: Color(0xFF4E97E8),
  accentBright: Color(0xFF93C0F3),
  onAccent: Color(0xFFFFFFFF),
  ring: Color(0xFFD3E0EE),
  error: Color(0xFFC6455C),
  headerGradientTop: Color(0xFFDCEAF8),
);

/// Light, soft pink — the light counterpart to Blossom.
const _rose = JellyColors(
  background: Color(0xFFFCF2F7),
  navSurface: Color(0xFFF4E4EC),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFF7E8F0),
  surfaceHigher: Color(0xFFEFD8E5),
  textPrimary: Color(0xFF261824),
  textSecondary: Color(0xFF5C4854),
  textTertiary: Color(0xFF897580),
  accent: Color(0xFFD8579E),
  accentAlt: Color(0xFFE372AF),
  accentBright: Color(0xFFF1A7D2),
  onAccent: Color(0xFFFFFFFF),
  ring: Color(0xFFEAD3E0),
  error: Color(0xFFC6455C),
  headerGradientTop: Color(0xFFF6E0EC),
);

// ─── ThemeData builder ───────────────────────────────────────────────

/// Turns a [JellyColors] palette + [Brightness] into the app's [ThemeData].
/// The palette is also attached as a [JellyColors] extension so widgets can
/// read it through `context.colors`.
abstract final class AppTheme {
  static ThemeData build(JellyColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      surface: c.surface,
    ).copyWith(
      primary: c.accent,
      secondary: c.accentAlt,
      surface: c.surface,
      error: c.error,
    );

    return base.copyWith(
      extensions: [c],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      // Desktop defaults to the zoom transition, which rasterises both routes
      // into snapshots before it animates — on a large window that costs a
      // visible hitch when the full-screen player opens. A fade-up is free.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkRipple.splashFactory,
      textTheme: _textTheme(GoogleFonts.interTextTheme(base.textTheme), c),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01 * 20,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.navSurface,
        indicatorColor: c.surfaceHigher,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? c.textPrimary : c.textSecondary,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        selectedIconTheme: IconThemeData(color: c.textPrimary),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(color: c.textSecondary),
        indicatorColor: c.surfaceHigher,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      dividerColor: c.ring,
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surfaceHigher,
        thumbColor: c.accent,
        trackHeight: 4,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          side: BorderSide(color: c.ring),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: TextStyle(color: c.textTertiary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.ring),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.accent),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, JellyColors c) {
    // Apply the text colours first, then tweak weights by *merging* onto the
    // resulting styles — replacing them outright would drop fontSize/colour
    // and make headings render as tiny, near-invisible body text.
    final applied = base.apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );
    return applied.copyWith(
      headlineLarge: applied.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: applied.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: applied.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: applied.bodySmall?.copyWith(color: c.textSecondary),
    );
  }
}
