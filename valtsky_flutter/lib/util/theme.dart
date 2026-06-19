import 'package:flutter/material.dart';

class ValtSkyTheme {
  static const Color primaryAccent = Color(0xFF0088CC); // Telegram Blue
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA000);
  static const Color error = Color(0xFFE53935);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        brightness: Brightness.light,
        primary: primaryAccent,
        surface: const Color(0xFFF5F7FA),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
        titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
        bodyMedium: TextStyle(color: Color(0xFF42474E)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryAccent,
        brightness: Brightness.dark,
        primary: primaryAccent,
        surface: const Color(0xFF000000), // Pure Black Surface
      ),
      scaffoldBackgroundColor: const Color(0xFF000000), // Midnight Black
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF121212), // Deep grey for non-glass elements
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
      ),
    );
  }
}
