import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zmusic/theme/app_theme.dart';

class ThemeState {
  final ThemeMode mode;
  final AppPalette palette;

  ThemeState({required this.mode, required this.palette});

  ThemeState copyWith({ThemeMode? mode, AppPalette? palette}) {
    return ThemeState(
      mode: mode ?? this.mode,
      palette: palette ?? this.palette,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const String _themeKey = 'theme_mode';
  static const String _paletteKey = 'theme_palette';

  @override
  ThemeState build() {
    _loadSettings();
    return ThemeState(mode: ThemeMode.dark, palette: AppPalette.mint);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString(_themeKey);
    final paletteString = prefs.getString(_paletteKey);

    ThemeMode mode = ThemeMode.dark;
    AppPalette palette = AppPalette.mint;

    if (themeModeString != null) {
      mode = ThemeMode.values.firstWhere(
        (m) => m.toString() == themeModeString,
        orElse: () => ThemeMode.dark,
      );
    }

    if (paletteString != null) {
      palette = AppPalette.values.firstWhere(
        (p) => p.toString() == paletteString,
        orElse: () => AppPalette.mint,
      );
    }

    state = ThemeState(mode: mode, palette: palette);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  Future<void> setPalette(AppPalette palette) async {
    state = state.copyWith(palette: palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.toString());
  }

  Future<void> toggleTheme() async {
    final newMode = state.mode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  bool get isDarkMode => state.mode == ThemeMode.dark;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(() {
  return ThemeNotifier();
});
