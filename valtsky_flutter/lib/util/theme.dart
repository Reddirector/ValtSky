import 'package:flutter/material.dart';

/// ValtSky Warm-Amber Design System
/// Enforces the single source of truth for all colors, typography tokens,
/// elevations, and geometric radii across Dark and Light modes.
class ValtSkyTheme {
  // ─── DARK PALETTE TOKENS ──────────────────────────────────────────────────
  static const Color darkCanvas = Color(0xFF0B0C0C);
  static const Color darkSurface = Color(0xFF141616);
  static const Color darkRaised = Color(0xFF1D2020);
  static const Color darkHairline = Color(0xFF2A2E2E);
  static const Color darkTextPrimary = Color(0xFFF2F5F4);
  static const Color darkTextSecondary = Color(0xFF98A09E);

  // ─── LIGHT PALETTE TOKENS ─────────────────────────────────────────────────
  static const Color lightCanvas = Color(0xFFE6ECEA);
  static const Color lightSurface = Color(0xFFF7FAF9);
  static const Color lightRaised = Color(0xFFDDE5E2);
  static const Color lightHairline = Color(0xFFC6D0CD);
  static const Color lightTextPrimary = Color(0xFF111514);
  static const Color lightTextSecondary = Color(0xFF55605D);

  // ─── ACCENT & INK TOKENS ──────────────────────────────────────────────────
  static const Color accentColor = Color(0xFF3DD6C6);
  static const Color amber = accentColor; // Alias for backward compatibility
  static const Color ink = Color(0xFF0B0C0C);
  static const Color lightAccentText = Color(0xFF0B6B63); // Accessible teal text/icon (> 5.3:1)
  static const Color lightAmberText = lightAccentText; // Alias for backward compatibility

  // ─── STATUS TOKENS ────────────────────────────────────────────────────────
  static const Color statusSynced = Color(0xFFA3D977); // Lime: does not blur with teal
  static const Color statusFailed = Color(0xFFE07A6B); // Coral
  static const Color statusInFlight = accentColor;     // In-flight = accent (#3DD6C6)

  // Semantic & compatibility mappings
  static const Color error = statusFailed;
  static const Color errorGlow = Color(0xFFC55A4C);
  static const Color success = statusSynced;
  static const Color warning = amber;
  static const Color info = amber;

  static const Color telegramBlue = amber;
  static const Color primaryAccent = amber;
  static const Color primaryAccentLight = amber;
  static const Color tertiaryLightSurface = lightCanvas;
  static const Color tertiaryDarkSurface = darkCanvas;
  static const Color tertiaryLightCard = lightSurface;
  static const Color tertiaryDarkCard = darkSurface;
  static const Color tertiaryLightBorder = lightHairline;
  static const Color tertiaryDarkBorder = darkHairline;
  static const Color tertiaryLightTrack = lightRaised;
  static const Color tertiaryDarkTrack = darkRaised;
  static const Color tertiaryLightMuted = lightTextSecondary;
  static const Color tertiaryDarkMuted = darkTextSecondary;

  // ─── GEOMETRY TOKENS ──────────────────────────────────────────────────────
  static const double radiusCard = 24.0;
  static const double radiusPill = 999.0;
  static const double gridUnit = 8.0;

  // ─── FONT FAMILY ──────────────────────────────────────────────────────────
  static const String fontFamily = 'Plus Jakarta Sans';

  // ─── CONTEXTUAL ACCESSORS ─────────────────────────────────────────────────
  static Color canvas(bool isDark) => isDark ? darkCanvas : lightCanvas;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color raised(bool isDark) => isDark ? darkRaised : lightRaised;
  static Color hairline(bool isDark) => isDark ? darkHairline : lightHairline;
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;

  /// Primary accent color: #3DD6C6 (teal)
  /// For fills/rings/buttons/active states.
  static Color accent(bool isDark) => accentColor;

  /// Accessible text/icon accent color on surfaces:
  /// In Dark mode: Teal (#3DD6C6, 9.7:1).
  /// In Light mode: Deep Teal (#0B6B63, > 5.3:1).
  static Color accentText(bool isDark) => isDark ? accentColor : lightAccentText;

  /// CTA panel background:
  /// In Dark mode: darkRaised (#1D2020).
  /// In Light mode: inverse ink (#0B0C0C) with cream text and teal button.
  static Color ctaPanelBackground(bool isDark) => isDark ? darkRaised : ink;

  // Backward-compatible accessors
  static Color primary(bool isDark) => accent(isDark);
  static Color secondary(bool isDark) => accentText(isDark);
  static Color tertiarySurface(bool isDark) => canvas(isDark);
  static Color tertiaryCard(bool isDark) => surface(isDark);
  static Color tertiaryBorder(bool isDark) => hairline(isDark);
  static Color tertiaryTrack(bool isDark) => raised(isDark);
  static Color tertiaryText(bool isDark) => textSecondary(isDark);

  // ─── TYPOGRAPHY HELPERS ───────────────────────────────────────────────────
  /// Big numeral display (Light 300, confident and clean)
  static TextStyle bigNumeral({required bool isDark, double fontSize = 44}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.5,
      color: textPrimary(isDark),
      height: 1.05,
    );
  }

  /// Small letter-spaced caps label (10.5-11pt, +1.2 letter spacing)
  static TextStyle capsLabel({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: color ?? textSecondary(isDark),
    );
  }

  /// Standard body regular (14-15px)
  static TextStyle body({required bool isDark, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: 14.0,
      fontWeight: weight,
      color: color ?? textPrimary(isDark),
      height: 1.4,
    );
  }

  // ─── LIGHT THEME ──────────────────────────────────────────────────────────
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: amber,
        onPrimary: ink,
        secondary: lightAmberText,
        onSecondary: Colors.white,
        tertiary: lightRaised,
        onTertiary: ink,
        error: statusFailed,
        onError: Colors.white,
        surface: lightSurface,
        onSurface: lightTextPrimary,
      ),
      scaffoldBackgroundColor: lightCanvas,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: lightHairline, width: 1.0),
        ),
        color: lightSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: lightTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: amber,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: ink);
          }
          return const IconThemeData(color: lightTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            color: lightTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: ink,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightHairline, width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w300, color: lightTextPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: lightTextPrimary, letterSpacing: -0.4),
        titleLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, color: lightTextPrimary),
        titleMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: lightTextPrimary),
        bodyLarge: TextStyle(fontFamily: fontFamily, color: lightTextPrimary, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamily: fontFamily, color: lightTextSecondary),
        bodySmall: TextStyle(fontFamily: fontFamily, color: lightTextSecondary),
      ),
    );
  }

  // ─── DARK THEME ───────────────────────────────────────────────────────────
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: amber,
        onPrimary: ink,
        secondary: amber,
        onSecondary: ink,
        tertiary: darkRaised,
        onTertiary: darkTextPrimary,
        error: statusFailed,
        onError: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkCanvas,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: darkHairline, width: 1.0),
        ),
        color: darkSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: darkTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: amber,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: ink);
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamily,
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: fontFamily,
            color: darkTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: ink,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkHairline, width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w300, color: darkTextPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: darkTextPrimary, letterSpacing: -0.4),
        titleLarge: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, color: darkTextPrimary),
        titleMedium: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: TextStyle(fontFamily: fontFamily, color: darkTextPrimary, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontFamily: fontFamily, color: darkTextSecondary),
        bodySmall: TextStyle(fontFamily: fontFamily, color: darkTextSecondary),
      ),
    );
  }
}
