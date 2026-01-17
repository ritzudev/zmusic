import 'package:flutter/material.dart';

class AppTheme {
  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0E0E2C);
  static const Color darkSurface = Color(0xFF19193E);
  static const Color darkPrimary = Color(0xFFD2E603);
  static const Color darkSecondary = Color(0xFF282855);
  static const Color darkOnBg = Colors.white;
  static const Color darkOnSurface = Colors.white;
  static const Color darkOnPrimary = Colors.black;

  // Light Theme Colors
  static const Color lightBg = Color(0xFFF0F0F3);
  static const Color lightSurface = Colors.white;
  static const Color lightPrimary = Colors.blue;
  static const Color lightSecondary = Color(0xFFE8E8EC);
  static const Color lightOnBg = Color(0xFF1A1A1A);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnPrimary = Colors.white;

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        surface: lightSurface,
        primary: lightPrimary,
        secondary: lightSecondary,
        onSurface: lightOnSurface,
        onPrimary: lightOnPrimary,
      ),
      scaffoldBackgroundColor: lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        iconTheme: IconThemeData(color: lightOnBg),
        titleTextStyle: TextStyle(
          color: lightOnBg,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        //filled: true,
        //fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIconColor: Colors.grey,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: darkSurface,
        primary: darkPrimary,
        secondary: darkSecondary,
        onSurface: darkOnSurface,
        onPrimary: darkOnPrimary,
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        iconTheme: IconThemeData(color: darkOnBg),
        titleTextStyle: TextStyle(
          color: darkOnBg,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Color(0xFF8080A5)),
        prefixIconColor: const Color(0xFF8080A5),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBg,
        selectedItemColor: darkPrimary,
        unselectedItemColor: Color(0xFF8080A5),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
