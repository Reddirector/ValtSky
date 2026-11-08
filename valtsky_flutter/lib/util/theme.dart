import 'package:flutter/material.dart';

/// ValtSky "Ink & Paper" Editorial Minimalism Design System
/// Implements monochrome editorial minimalism with large ink cap slab (radius 40),
/// floating paper cards, hairline outlines, Outfit Light 300 numerals, and Inter body typography.
class ValtSkyTheme {
  // ─── LIGHT "PAPER" PALETTE TOKENS ──────────────────────────────────────────
  static const Color lightCanvas = Color(0xFFF2F2F0);       // Warm paper base
  static const Color lightSurface1 = Color(0xFFFFFFFF);     // Floating white card
  static const Color lightSurface2 = Color(0xFFEAEAE7);     // Secondary card / chip fill
  static const Color lightSurface3 = Color(0xFFDADAD6);     // Recessed track / dividers
  static const Color lightHairline = Color(0xFFD4D4D0);     // 1px hairline border
  static const Color lightInk = Color(0xFF0E0E10);          // Primary ink text & CTA fill
  static const Color lightText2 = Color(0xFF55555B);        // Secondary text
  static const Color lightText3 = Color(0xFF66666C);        // Tertiary / minimum allowed text
  static const Color lightCapSlab = Color(0xFF0E0E10);      // Solid ink cap slab
  static const Color lightCapSlabText = Color(0xFFF1F1EE);  // Contrast text on light cap slab
  static const Color lightAccent = Color(0xFF4650D6);       // Restrained logo indigo (white text)
  static const Color lightSynced = Color(0xFF1F7A52);       // Muted forest sage
  static const Color lightFailed = Color(0xFFC23838);       // Restrained editorial crimson

  // ─── DARK "INK" PALETTE TOKENS ─────────────────────────────────────────────
  static const Color darkCanvas = Color(0xFF0A0A0B);        // Deep matte ink canvas
  static const Color darkSurface1 = Color(0xFF141416);      // Dark card surface
  static const Color darkSurface2 = Color(0xFF1C1C1F);      // Secondary dark surface
  static const Color darkSurface3 = Color(0xFF26262A);      // Recessed track / dividers
  static const Color darkHairline = Color(0xFF2C2C30);      // 1px hairline outline
  static const Color darkTextPrimary = Color(0xFFF1F1EE);   // Primary text (paper white)
  static const Color darkText2 = Color(0xFFA3A3A8);         // Secondary text
  static const Color darkText3 = Color(0xFF8A8A90);         // Tertiary / dimmest allowed text
  static const Color darkCapSlab = Color(0xFF1C1C1F);       // Subtle dark slab with 5% highlight
  static const Color darkCapSlabText = Color(0xFFF1F1EE);   // Contrast text on dark cap slab
  static const Color darkAccent = Color(0xFF8C99FF);        // Brightened logo indigo (ink text)
  static const Color darkSynced = Color(0xFF6FD3A5);        // Soft mint sage
  static const Color darkFailed = Color(0xFFFF8A8A);        // Soft editorial coral

  // ─── STATUS & SEMANTIC TOKENS ──────────────────────────────────────────────
  static const Color ink = Color(0xFF0E0E10);               // High-contrast ink
  static const Color paper = Color(0xFFF1F1EE);             // High-contrast paper white

  // Compatibility aliases
  static const Color darkOverlay = darkSurface2;
  static const Color darkAccent2 = darkAccent;
  static const Color darkAqua = darkAccent;
  static const Color lightAccentFill = lightAccent;
  static const Color lightAccentText = lightAccent;
  static const Color darkTextSecondary = darkText2;
  static const Color darkTextTertiary = darkText3;
  static const Color lightTextPrimary = lightInk;
  static const Color lightTextSecondary = lightText2;
  static const Color statusSynced = darkSynced;
  static const Color statusFailed = darkFailed;
  static const Color statusInFlight = darkAccent;
  static const Color accentColor = darkAccent;
  static const Color amber = darkAccent;
  static const Color lightAmberText = lightAccent;
  static const Color error = darkFailed;
  static const Color success = darkSynced;
  static const Color warning = darkAccent;
  static const Color info = darkAccent;
  static const Color telegramBlue = darkAccent;
  static const Color primaryAccent = darkAccent;
  static const Color primaryAccentLight = lightAccent;

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
  static const Color tertiaryLightMuted = lightText2;
  static const Color tertiaryDarkMuted = darkText2;

  // ─── GEOMETRY TOKENS ──────────────────────────────────────────────────────
  static const double radiusCapSlab = 40.0;                 // Signature organic bottom curve
  static const double radiusCard = 28.0;                    // Standard cards
  static const double radiusTile = 24.0;                    // Bento and stat tiles
  static const double radiusPill = 999.0;                   // Fully rounded chips and CTA buttons
  static const double gridUnit = 8.0;

  // ─── TYPOGRAPHY TOKENS ────────────────────────────────────────────────────
  static const String fontFamilyDisplay = 'Outfit';         // Headings, titles, Light 300 numerals
  static const String fontFamilyBody = 'Inter';             // Body, labels, caps
  static const String fontFamily = fontFamilyBody;

  // ─── CONTEXTUAL COLOR ACCESSORS ───────────────────────────────────────────
  static Color canvas(bool isDark) => isDark ? darkCanvas : lightCanvas;
  static Color surface(bool isDark, {int level = 1}) {
    if (isDark) {
      switch (level) {
        case 2: return darkSurface2;
        case 3: return darkSurface3;
        case 4: return darkSurface2;
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

  static Color capSlab(bool isDark) => isDark ? darkCapSlab : lightCapSlab;
  static Color capSlabText(bool isDark) => isDark ? darkCapSlabText : lightCapSlabText;
  static Color raised(bool isDark) => isDark ? darkSurface2 : lightSurface2;
  static Color hairline(bool isDark) => isDark ? darkHairline : lightHairline;
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color textTertiary(bool isDark) => isDark ? darkTextTertiary : lightText3;
  static Color accent(bool isDark) => isDark ? darkAccent : lightAccent;
  static Color accentText(bool isDark) => isDark ? darkAccent : lightAccent;
  static Color synced(bool isDark) => isDark ? darkSynced : lightSynced;
  static Color failed(bool isDark) => isDark ? darkFailed : lightFailed;

  // Primary CTA Button colors (Light: ink fill + paper text; Dark: paper fill + ink text)
  static Color primaryCtaFill(bool isDark) => isDark ? paper : lightInk;
  static Color primaryCtaText(bool isDark) => isDark ? darkCanvas : paper;

  // Backward-compatible accessors
  static Color primary(bool isDark) => accent(isDark);
  static Color secondary(bool isDark) => accentText(isDark);
  static Color tertiarySurface(bool isDark) => canvas(isDark);
  static Color tertiaryCard(bool isDark) => surface(isDark);
  static Color tertiaryBorder(bool isDark) => hairline(isDark);
  static Color tertiaryTrack(bool isDark) => surface(isDark, level: 3);
  static Color tertiaryText(bool isDark) => textSecondary(isDark);
  static Color ctaPanelBackground(bool isDark) => isDark ? darkSurface2 : lightSurface2;

  // Gradients (restrained 5% accent budget)
  static Gradient? primaryCtaGradient(bool isDark) => null; // Editorial solid fills
  static Gradient? activeDockGradient(bool isDark) => null;
  static Gradient heroRingGradient(bool isDark) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? const [darkAccent, Color(0xFFA78BFA)]
          : const [lightAccent, Color(0xFF6B78F0)],
    );
  }

  // ─── DEPTH DECORATOR WITH 1PX HAIRLINE ────────────────────────────────────
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
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ─── TYPOGRAPHY HELPERS ───────────────────────────────────────────────────
  /// Hero Numeral (Outfit Light 300, 56pt)
  static TextStyle heroNumeral({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 56,
      fontWeight: FontWeight.w300,
      letterSpacing: -1.2,
      color: color ?? textPrimary(isDark),
      height: 1.0,
    );
  }

  /// Stat Numeral (Outfit Light 300, 36pt)
  static TextStyle statNumeral({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 36,
      fontWeight: FontWeight.w300,
      letterSpacing: -0.6,
      color: color ?? textPrimary(isDark),
      height: 1.05,
    );
  }

  /// Screen Title (Outfit SemiBold 600, 28pt)
  static TextStyle screenTitle({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyDisplay,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: color ?? textPrimary(isDark),
    );
  }

  /// Small Caps Section Header (Inter Bold 700, 11pt, +1.0 tracking)
  static TextStyle capsLabel({required bool isDark, Color? color}) {
    return TextStyle(
      fontFamily: fontFamilyBody,
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: color ?? textSecondary(isDark),
    );
  }

  /// Standard Body (Inter 14-15pt, line-height 1.45)
  static TextStyle body({
    required bool isDark,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double fontSize = 14.5,
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
        primary: lightInk,
        onPrimary: paper,
        secondary: lightAccent,
        onSecondary: Colors.white,
        tertiary: lightSurface2,
        onTertiary: lightInk,
        error: lightFailed,
        onError: Colors.white,
        surface: lightSurface1,
        onSurface: lightInk,
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
        iconTheme: IconThemeData(color: lightCapSlabText),
        titleTextStyle: TextStyle(
          fontFamily: fontFamilyDisplay,
          color: lightCapSlabText,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface1,
        indicatorColor: lightSurface2,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: lightInk);
          }
          return const IconThemeData(color: lightText2);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamilyBody,
              color: lightInk,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: fontFamilyBody,
            color: lightText2,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightInk,
          foregroundColor: paper,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightInk,
          side: const BorderSide(color: lightHairline, width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w300, color: lightInk, letterSpacing: -1.0),
        headlineMedium: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w600, color: lightInk, letterSpacing: -0.5),
        titleLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w600, color: lightInk),
        titleMedium: TextStyle(fontFamily: fontFamilyBody, fontWeight: FontWeight.w600, color: lightInk),
        bodyLarge: TextStyle(fontFamily: fontFamilyBody, color: lightInk, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: TextStyle(fontFamily: fontFamilyBody, color: lightText2, height: 1.45),
        bodySmall: TextStyle(fontFamily: fontFamilyBody, color: lightText3),
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
        primary: paper,
        onPrimary: darkCanvas,
        secondary: darkAccent,
        onSecondary: darkCanvas,
        tertiary: darkSurface2,
        onTertiary: darkTextPrimary,
        error: darkFailed,
        onError: darkCanvas,
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
        iconTheme: IconThemeData(color: darkCapSlabText),
        titleTextStyle: TextStyle(
          fontFamily: fontFamilyDisplay,
          color: darkCapSlabText,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface1,
        indicatorColor: darkSurface2,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: paper);
          }
          return const IconThemeData(color: darkText2);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: fontFamilyBody,
              color: paper,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(
            fontFamily: fontFamilyBody,
            color: darkText2,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: paper,
          foregroundColor: darkCanvas,
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
        headlineLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w300, color: darkTextPrimary, letterSpacing: -1.0),
        headlineMedium: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w600, color: darkTextPrimary, letterSpacing: -0.5),
        titleLarge: TextStyle(fontFamily: fontFamilyDisplay, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleMedium: TextStyle(fontFamily: fontFamilyBody, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: TextStyle(fontFamily: fontFamilyBody, color: darkTextPrimary, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: TextStyle(fontFamily: fontFamilyBody, color: darkText2, height: 1.45),
        bodySmall: TextStyle(fontFamily: fontFamilyBody, color: darkText3),
      ),
    );
  }
}
