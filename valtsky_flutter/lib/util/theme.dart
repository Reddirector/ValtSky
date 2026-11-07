import 'package:flutter/material.dart';

/// ValtSky Unified Azure/Sapphire Theme Engine with Black Midnight Base & Light Royal Blue Buttons
/// Enforces a strict 3-color family hierarchy (Primary, Secondary, Tertiary shades of Blue/Midnight):
/// - Primary: Light Royal Blue (Action CTAs, dominant switches, active states)
/// - Secondary: Electric Cerulean / Sky Blue (Telemetry, speed meters, progress fills, active accents)
/// - Tertiary: Pure Black Midnight / Slate (Card surfaces, boundaries, neutral tracks, muted text)
class ValtSkyTheme {
  // ─── THREE-COLOR SINGLE FAMILY HIERARCHY (ROYAL BLUE / MIDNIGHT FAMILY) ───

  // 1. PRIMARY SHADE: Simple Light Royal Blue (Buttons & Primary CTAs)
  static const Color lightRoyalBlue = Color(0xFF4169E1); // Classic Light Royal Blue (4169E1)
  static const Color lightRoyalBlueHover = Color(0xFF4F75F5); // Hover / Highlight Light Royal Blue
  static const Color primaryLight = Color(0xFF3B64DE); // Light Royal Blue (Light Mode)
  static const Color primaryDark = Color(0xFF4169E1);  // Vivid Light Royal Blue (Dark Mode)

  // 2. SECONDARY SHADE: Electric Cerulean / Sky Blue
  static const Color secondaryLight = Color(0xFF0284C7); // Vivid Sky Blue (Sky 600)
  static const Color secondaryDark = Color(0xFF38BDF8);  // Electric Sky Blue (Sky 400)

  // 3. TERTIARY SHADE: Black Midnight / Ice Mist (Surfaces, Borders, Tracks)
  static const Color tertiaryLightSurface = Color(0xFFF0F7FF); // Soft Ice Sky Blue Tint
  static const Color tertiaryLightCard = Color(0xFFFFFFFF);    // Clean Card Surface
  static const Color tertiaryLightBorder = Color(0xFFBAE6FD);  // Powder Sky Border (Sky 200)
  static const Color tertiaryLightTrack = Color(0xFFE0F2FE);   // Subtle Telemetry Track
  static const Color tertiaryLightMuted = Color(0xFF64748B);   // Slate Tertiary Muted Text

  // Black Midnight Base & Surface Hierarchy
  static const Color blackMidnight = Color(0xFF000000);        // Deep Pure Midnight Black
  static const Color tertiaryDarkSurface = Color(0xFF000000);  // Black Midnight Scaffold Surface
  static const Color tertiaryDarkCard = Color(0xFF0A0D14);     // Midnight Surface Card
  static const Color tertiaryDarkBorder = Color(0xFF141A26);   // Midnight Slate Boundary
  static const Color tertiaryDarkTrack = Color(0xFF0D121B);    // Midnight Telemetry Track
  static const Color tertiaryDarkMuted = Color(0xFF8899AC);    // Slate Tertiary Muted Text

  // Backward-compatible semantic and telegram accents
  static const Color primaryAccent = primaryDark;
  static const Color primaryAccentLight = primaryLight;
  static const Color telegramBlue = secondaryLight;

  // Semantic Alerts (Preserved for system safety and notifications)
  static const Color error = Color(0xFFEF4444);
  static const Color errorGlow = Color(0xFFDC2626);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = secondaryLight;

  // Helpers for contextual palette resolution
  static Color primary(bool isDark) => isDark ? primaryDark : primaryLight;
  static Color secondary(bool isDark) => isDark ? secondaryDark : secondaryLight;
  static Color tertiarySurface(bool isDark) => isDark ? tertiaryDarkSurface : tertiaryLightSurface;
  static Color tertiaryCard(bool isDark) => isDark ? tertiaryDarkCard : tertiaryLightCard;
  static Color tertiaryBorder(bool isDark) => isDark ? tertiaryDarkBorder : tertiaryLightBorder;
  static Color tertiaryTrack(bool isDark) => isDark ? tertiaryDarkTrack : tertiaryLightTrack;
  static Color tertiaryText(bool isDark) => isDark ? tertiaryDarkMuted : tertiaryLightMuted;

  // ─── LIGHT THEME ──────────────────────────────────────────────────────────
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryLight,
        onPrimary: Colors.white,
        secondary: secondaryLight,
        onSecondary: Colors.white,
        tertiary: tertiaryLightBorder,
        onTertiary: primaryLight,
        error: error,
        onError: Colors.white,
        surface: tertiaryLightCard,
        onSurface: Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: tertiaryLightSurface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: tertiaryLightBorder, width: 1),
        ),
        color: tertiaryLightCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryLight),
        titleTextStyle: TextStyle(
          color: primaryLight,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tertiaryLightCard,
        indicatorColor: tertiaryLightTrack,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryLight);
          }
          return const IconThemeData(color: tertiaryLightMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryLight, fontSize: 12, fontWeight: FontWeight.w800);
          }
          return const TextStyle(color: tertiaryLightMuted, fontSize: 12, fontWeight: FontWeight.w600);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryLight, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.4),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        bodyLarge: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: tertiaryLightMuted),
        bodySmall: TextStyle(color: Color(0xFF94A3B8)),
      ),
    );
  }

  // ─── DARK THEME ───────────────────────────────────────────────────────────
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryDark,
        onPrimary: Colors.white,
        secondary: secondaryDark,
        onSecondary: Colors.black,
        tertiary: tertiaryDarkBorder,
        onTertiary: secondaryDark,
        error: error,
        onError: Colors.white,
        surface: tertiaryDarkCard,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: tertiaryDarkSurface,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: tertiaryDarkBorder, width: 1),
        ),
        color: tertiaryDarkCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: secondaryDark),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF000000),
        indicatorColor: const Color(0xFF101C33),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryDark);
          }
          return const IconThemeData(color: tertiaryDarkMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryDark, fontSize: 12, fontWeight: FontWeight.w800);
          }
          return const TextStyle(color: tertiaryDarkMuted, fontSize: 12, fontWeight: FontWeight.w600);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryDark,
          side: const BorderSide(color: primaryDark, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF1F5F9)),
        bodyLarge: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: tertiaryDarkMuted),
        bodySmall: TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }
}
