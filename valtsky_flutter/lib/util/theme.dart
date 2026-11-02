import 'package:flutter/material.dart';

/// ValtSky Noir Monochrome Theme Engine
/// Enforces a sleek Black & White minimalist UI form, while reserving
/// vibrant high-contrast colors strictly for alerts, popups, and diagnostic states.
class ValtSkyTheme {
  // ─── MONOCHROME PRIMARY PALETTE (BLACK & WHITE UI) ────────────────
  static const Color monoBlack = Color(0xFF000000);
  static const Color monoNearBlack = Color(0xFF09090B);
  static const Color monoDarkSurface = Color(0xFF121214);
  static const Color monoDarkCard = Color(0xFF18181B);
  static const Color monoDarkBorder = Color(0xFF27272A);
  static const Color monoDarkTextSecondary = Color(0xFFA1A1AA);
  static const Color monoDarkTextMuted = Color(0xFF71717A);

  static const Color monoWhite = Color(0xFFFFFFFF);
  static const Color monoOffWhite = Color(0xFFFAFAFA);
  static const Color monoLightSurface = Color(0xFFF4F4F5);
  static const Color monoLightCard = Color(0xFFFFFFFF);
  static const Color monoLightBorder = Color(0xFFE4E4E7);
  static const Color monoLightTextSecondary = Color(0xFF71717A);
  static const Color monoLightTextMuted = Color(0xFFA1A1AA);

  // Standard UI accents in Black & White form
  static const Color primaryAccent = Color(0xFFFFFFFF); // High-contrast White in Dark
  static const Color primaryAccentLight = Color(0xFF000000); // Pitch Black in Light

  // ─── VIBRANT SEMANTIC COLORS (FOR ALERTS, POPUPS & STATUS BADGES) ──
  static const Color error = Color(0xFFEF4444); // Crimson Alert
  static const Color errorGlow = Color(0xFFDC2626);
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Amber Warning
  static const Color info = Color(0xFF0EA5E9); // Electric Blue Alert
  static const Color telegramBlue = Color(0xFF2AABEE); // Official Telegram Sky Blue

  // Light Theme (Clean Crisp Minimalist Black & White)
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: monoBlack,
        onPrimary: monoWhite,
        secondary: Color(0xFF27272A),
        onSecondary: monoWhite,
        error: error,
        onError: monoWhite,
        surface: monoLightCard,
        onSurface: monoBlack,
      ),
      scaffoldBackgroundColor: monoWhite,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: monoLightBorder, width: 1),
        ),
        color: monoLightCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: monoBlack),
        titleTextStyle: TextStyle(
          color: monoBlack,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: monoWhite,
        indicatorColor: monoBlack,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: monoWhite);
          }
          return const IconThemeData(color: monoBlack);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: monoBlack, fontSize: 12, fontWeight: FontWeight.w800);
          }
          return const TextStyle(color: monoLightTextSecondary, fontSize: 12, fontWeight: FontWeight.w600);
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: monoBlack, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: monoBlack, letterSpacing: -0.4),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: monoBlack),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: monoBlack),
        bodyLarge: TextStyle(color: Color(0xFF27272A), fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: monoLightTextSecondary),
        bodySmall: TextStyle(color: monoLightTextMuted),
      ),
    );
  }

  // Dark Theme (Pure Noir Obsidian Black & White)
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: monoWhite,
        onPrimary: monoBlack,
        secondary: Color(0xFFE4E4E7),
        onSecondary: monoBlack,
        error: error,
        onError: monoWhite,
        surface: monoDarkSurface,
        onSurface: monoWhite,
      ),
      scaffoldBackgroundColor: monoNearBlack,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: monoDarkBorder, width: 1),
        ),
        color: monoDarkCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: monoWhite),
        titleTextStyle: TextStyle(
          color: monoWhite,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: monoNearBlack,
        indicatorColor: monoWhite,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: monoBlack);
          }
          return const IconThemeData(color: monoDarkTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: monoWhite, fontSize: 12, fontWeight: FontWeight.w800);
          }
          return const TextStyle(color: monoDarkTextMuted, fontSize: 12, fontWeight: FontWeight.w600);
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: monoWhite, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: monoWhite, letterSpacing: -0.4),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: monoWhite),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFAFAFA)),
        bodyLarge: TextStyle(color: Color(0xFFE4E4E7), fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: monoDarkTextSecondary),
        bodySmall: TextStyle(color: monoDarkTextMuted),
      ),
    );
  }
}
