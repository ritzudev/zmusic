import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final String youtubeCookies;

  SettingsState({required this.youtubeCookies});

  SettingsState copyWith({String? youtubeCookies}) {
    return SettingsState(
      youtubeCookies: youtubeCookies ?? this.youtubeCookies,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _youtubeCookiesKey = 'youtube_cookies';

  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState(youtubeCookies: '');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCookies = prefs.getString(_youtubeCookiesKey);
    
    state = SettingsState(
      youtubeCookies: savedCookies ?? '',
    );
  }

  Future<void> setYoutubeCookies(String cookies) async {
    final trimmedCookies = cookies.trim();
    state = state.copyWith(youtubeCookies: trimmedCookies);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_youtubeCookiesKey, trimmedCookies);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
