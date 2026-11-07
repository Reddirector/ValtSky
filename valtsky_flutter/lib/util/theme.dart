import 'package:flutter/material.dart';

/// ValtSky "Night-Sky Vault" Design System
/// Implements deep navy-ink canvas, indigo-violet light, calm glow, and multi-tier surfaces.
class ValtSkyTheme {
  // ─── DARK PALETTE TOKENS (NIGHT-SKY OLED) ──────────────────────────────────
  static const Color darkCanvas = Color(0xFF070A14);     // Ink navy
  static const Color darkSurface1 = Color(0xFF0D1220);    // Card base
  static const Color darkSurface2 = Color(0xFF141B2E);    // Elevated tiles & inputs
  static const Color darkSurface3 = Color(0xFF1C2540);    // Recessed tracks & rings
  static const Color darkOverlay = Color(0xFF242F52);     // Sheets, modals, menus
  static const Color darkHairline = Color(0x992A3558);    // 60% opacity of #2A3558
  static const Color darkTextPrimary = Color(0xFFE8ECF8); // 16.74:1 AAA contrast
  static const Color darkTextSecondary = Color(0xFF9AA4C2); // 7.96:1 AAA contrast
  static const Color darkTextTertiary = Color(0xFF7A85A8);  // 5.41:1 AA contrast (minimum)
  static const Color darkAccent = Color(0xFF7C8CFF);      // Logo indigo brightened
  static const Color darkAccent2 = Color(0xFFA78BFA);     // Violet (gradient end only)
  static const Color darkAqua = Color(0xFF5EE1F0);        // In-flight active transfer glow only

  // ─── LIGHT PALETTE TOKENS ─────────────────────────────────────────────────
  static const Color lightCanvas = Color(0xFFF3F5FC);
  static const Color lightSurface1 = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFE8ECF8);
  static const Color lightSurface3 = Color(0xFFDCE2F4);
  static const Color lightHairline = Color(0xFFD5DBEE);
  static const Color lightTextPrimary = Color(0xFF0E1330);
  static const Color lightTextSecondary = Color(0xFF4A5478);
  static const Color lightAccentFill = Color(0xFF4F5BD5);  // White text on it
  static const Color lightAccentText = Color(0xFF3F4BC4);  // 6.97:1 on light surface

  // ─── STATUS TOKENS ────────────────────────────────────────────────────────
  static const Color statusSynced = Color(0xFF5FD3A0);    // Mint
  static const Color statusFailed = Color(0xFFFF7A8A);    // Soft Coral
  static const Color ink = Color(0xFF070A14);             // High-contrast ink on accent fills

  // ─── COMPATIBILITY ALIASES ────────────────────────────────────────────────
  static const Color accentColor = darkAccent;
  static const Color amber = darkAccent;
  static const Color lightAmberText = lightAccentText;
  static const Color statusInFlight = darkAqua;
  static const Color error = statusFailed;
  static const Color success = statusSynced;
  static const Color warning = darkAccent;
  static const Color info = darkAqua;
  static const Color telegramBlue = darkAccent;
  static const Color primaryAccent = darkAccent;
  static const Color primaryAccentLight = lightAccentFill;

  // Backward surface mappings
  static const Color darkSurface = darkSurface1;
  static const Color darkRaised = darkSurface2;
  static const Color lightSurface = lightSurface1;
  static const Color lightRaised = lightSurface2;
  static const Color tertiaryLightSurface = lightCanvas;
  static const Color tertiaryDarkSurface = darkCanvas;
  static const Color tertiaryLightCard = lightSurface1;
  static const Color tertiaryDarkCard = darkSurface1;
  static const Color tertiaryLightBorder = lightHairline;
  static const Color tertiaryDarkBorder = darkHairline;
  static const Color tertiaryLightTrack = lightSurface3;
  static const Color tertiaryDarkTrack = darkSurface3;
  static const Color tertiaryLightMuted = lightTextSecondary;
  static const Color tertiaryDarkMuted = darkTextSecondary;

  // ─── GEOMETRY TOKENS ──────────────────────────────────────────────────────
  static const double radiusCard = 28.0;
  static const double radiusTile = 24.0;
  static const double radiusPill = 999.0;
  static const double gridUnit = 8.0;

  // ─── TYPOGRAPHY TOKENS ────────────────────────────────────────────────────
  static const String fontFamilyDisplay = 'Sora';
  static const String fontFamilyBody = 'Inter';
  static const String fontFamily = fontFamilyBody; // Default body family

  // ─── CONTEXTUAL COLOR ACCESSORS ───────────────────────────────────────────
  static Color canvas(bool isDark) => isDark ? darkCanvas : lightCanvas;
  static Color surface(bool isDark, {int level = 1}) {
    if (isDark) {
      switch (level) {
        case 2: return darkSurface2;
        case 3: return darkSurface3;
        case 4: return darkOverlay;
        default: return darkSurface1;
      }
    } else {
      switch (level) {
        case 2: return lightSurface2;
        case 3: return lightSurface3;
        default: return lightSurface1;
      }
    }
  }

  static Color raised(bool isDark) => isDark ? darkSurface2 : lightSurface2;
  static Color hairline(bool isDark) => isDark ? darkHairline : lightHairline;
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color textTertiary(bool isDark) => isDark ? darkTextTertiary : lightTextSecondary;

  static Color accent(bool isDark) => isDark ? darkAccent : lightAccentFill;
  static Color accentText(bool isDark) => isDark ? darkAccent : lightAccentText;
  static Color ctaPanelBackground(bool isDark) => isDark ? darkSurface2 : ink;

  // Gradients (permitted ONLY on: hero ring head, primary CTA, active dock indicator)
  static Gradient primaryCtaGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [darkAccent, darkAccent2]
          : const [lightAccentFill, Color(0xFF7C8CFF)],
    );
  }

  static Gradient activeDockGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [darkAccent, darkAccent2]
          : const [lightAccentFill, Color(0xFF6B78F0)],
    );
  }

  static Gradient heroRingGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [darkAccent, darkAccent2],
    );
  }

  // Backward-compatible accessors
  static Color primary(bool isDark) => accent(isDark);
  static Color secondary(bool isDark) => accentText(isDark);
  static Color tertiarySurface(bool isDark) => canvas(isDark);
  static Color tertiaryCard(bool isDark) => surface(isDark);
  static Color tertiaryBorder(bool isDark) => hairline(isDark);
  static Color tertiaryTrack(bool isDark) => surface(isDark, level: 3);
  static Color tertiaryText(bool isDark) => textSecondary(isDark);

  // ─── DEPTH DECORATOR WITH 1PX INNER TOP HIGHLIGHT ─────────────────────────
  static BoxDecoration cardDecoration({
    required bool isDark,
    int surfaceLevel = 1,
    double radius = radiusCard,
    bool withGlow = false,
    Color? borderColor,
  }) {
    final bg = surface(isDark, level: surfaceLevel);
    final borderCol = borderColor ?? hairline(isDark);

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderCol, width: 1.0),
      boxShadow: [
        if (withGlow && isDark)
          BoxShadow(
            color: darkAccent.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFF0E1330).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ─── TYPOGRAPHY HELPERS ───────────────────────────────────────────────────
  /// Large Hero Numeral (Sora Light 300, 56pt)
  static TextStyle heroNumeral({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 56,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.0,
      color: color ?? textPrimary(isDark),
      height: 1.0,
    );
  }

  /// Stat Numeral (Sora Light 300, 32pt)
  static TextStyle statNumeral({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 32,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.5,
      color: color ?? textPrimary(isDark),
      height: 1.1,
    );
  }

  /// Large Title (Sora SemiBold 600, 22pt)
  static TextStyle screenTitle({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      color: color ?? textPrimary(isDark),
    );
  }

  /// Small Caps Section Header (Inter 11pt, +1.0 letter-spacing)
  static TextStyle capsLabel({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: color ?? textSecondary(isDark),
    );
  }

  /// Standard Body (Inter 14-15pt, line-height 1.4+)
  static TextStyle body({
    required bool isDark,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double fontSize = 14.0,
  }) {
    return TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: fontSize,
      fontWeight: weight,
      color: color ?? textPrimary(isDark),
      height: 1.45,
    );
  }

  // Backward-compatible bigNumeral
  static TextStyle bigNumeral({required bool isDark, double fontSize = 44}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.5,
      color: textPrimary(isDark),
      height: 1.05,
    );
  }

  // ─── LIGHT THEME BUILDER ──────────────────────────────────────────────────
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamilyBody,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: lightAccentFill,
        onPrimary: Colors.white,
        secondary: lightAccentText,
        onSecondary: Colors.white,
        tertiary: lightSurface2,
        onTertiary: lightTextPrimary,
        error: statusFailed,
        onError: Colors.white,
        surface: lightSurface1,
        onSurface: lightTextPrimary,
      ),
      scaffoldBackgroundColor: lightCanvas,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: lightHairline, width: 1.0),
        ),
        color: lightSurface1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          fontFamily: fontFamilyDisplay,
          color: lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface1,
        indicatorColor: lightSurface2,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: lightAccentFill);
          }
          return const IconThemeData(color: lightTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamilyBody,
              color: lightAccentFill,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: fontFamilyBody,
            color: lightTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightAccentFill,
          foregroundColor: Colors.white,
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
        headlineLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w300, color: lightTextPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w600, color: lightTextPrimary, letterSpacing: -0.4),
        titleLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w700, color: lightTextPrimary),
        titleMedium: TextStyle(fontFamily: fontFamilyBody, fontWeight: FontWeight.w600, color: lightTextPrimary),
        bodyLarge: TextStyle(fontFamily: fontFamilyBody, color: lightTextPrimary, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: TextStyle(fontFamily: fontFamilyBody, color: lightTextSecondary, height: 1.45),
        bodySmall: TextStyle(fontFamily: fontFamilyBody, color: lightTextSecondary),
      ),
    );
  }

  // ─── DARK THEME BUILDER ───────────────────────────────────────────────────
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamilyBody,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: darkAccent,
        onPrimary: ink,
        secondary: darkAccent2,
        onSecondary: ink,
        tertiary: darkSurface2,
        onTertiary: darkTextPrimary,
        error: statusFailed,
        onError: Colors.white,
        surface: darkSurface1,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkCanvas,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: darkHairline, width: 1.0),
        ),
        color: darkSurface1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          fontFamily: fontFamilyDisplay,
          color: darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface1,
        indicatorColor: darkSurface2,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: darkAccent);
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamilyBody,
              color: darkAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: fontFamilyBody,
            color: darkTextSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent,
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
        headlineLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w300, color: darkTextPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w600, color: darkTextPrimary, letterSpacing: -0.4),
        titleLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w700, color: darkTextPrimary),
        titleMedium: TextStyle(fontFamily: fontFamilyBody, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: TextStyle(fontFamily: fontFamilyBody, color: darkTextPrimary, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: TextStyle(fontFamily: fontFamilyBody, color: darkTextSecondary, height: 1.45),
        bodySmall: TextStyle(fontFamily: fontFamilyBody, color: darkTextSecondary),
      ),
    );
  }
}
