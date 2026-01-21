import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppPalette { mint, sunset, ocean, royal }

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

  // Palette definition
  static Map<AppPalette, Color> paletteAccents = {
    AppPalette.mint: const Color(0xFF2A945F),
    AppPalette.sunset: const Color(0xFFD35400),
    AppPalette.ocean: const Color(0xFF3498DB),
    AppPalette.royal: const Color(0xFF8E44AD),
  };

  static Map<AppPalette, Color> paletteBackgrounds = {
    AppPalette.mint: const Color(0xFF0C1011),
    AppPalette.sunset: const Color(0xFF14100E),
    AppPalette.ocean: const Color(0xFF0C1117),
    AppPalette.royal: const Color(0xFF120E16),
  };

  static ThemeData get light => lightWithPalette(AppPalette.mint);

  static ThemeData lightWithPalette(AppPalette palette) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: paletteAccents[palette],
      appBarTheme: const AppBarTheme(elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get dark => darkWithPalette(AppPalette.mint);

  static ThemeData darkWithPalette(AppPalette palette) {
    final primaryColor = paletteAccents[palette]!;
    final bgColor = paletteBackgrounds[palette]!;
    final cardColor = Color.alphaBlend(Colors.white.withOpacity(0.05), bgColor);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme:
          GoogleFonts.montserratTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
          ).copyWith(
            displayLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            displayMedium: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
            ),
            displaySmall: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            headlineLarge: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
            ),
            headlineMedium: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
            ),
            headlineSmall: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
            ),
          ),
      colorScheme: ColorScheme.dark(
        surface: cardColor,
        primary: primaryColor,
        secondary: bgColor,
        onSurface: darkOnSurface,
        onPrimary: bgColor,
      ),
      scaffoldBackgroundColor: bgColor,
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: darkOnBg,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(color: primaryColor),
      primaryIconTheme: IconThemeData(color: primaryColor),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: darkOnSurface.withOpacity(0.5)),
        prefixIconColor: primaryColor,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: darkOnSurface.withOpacity(0.4),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
