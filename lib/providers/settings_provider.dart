import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final String cobaltUrl;
  final String youtubeCookies;

  SettingsState({required this.cobaltUrl, required this.youtubeCookies});

  SettingsState copyWith({String? cobaltUrl, String? youtubeCookies}) {
    return SettingsState(
      cobaltUrl: cobaltUrl ?? this.cobaltUrl,
      youtubeCookies: youtubeCookies ?? this.youtubeCookies,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _cobaltUrlKey = 'cobalt_api_url';
  static const String _youtubeCookiesKey = 'youtube_cookies';
  // Usamos el endpoint del servidor privado en Render como predeterminado
  static const String _defaultCobaltUrl = 'https://zmusic-server.onrender.com';

  @override
  SettingsState build() {
    _loadSettings();
    return SettingsState(cobaltUrl: _defaultCobaltUrl, youtubeCookies: '');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_cobaltUrlKey);
    final savedCookies = prefs.getString(_youtubeCookiesKey);
    
    state = SettingsState(
      cobaltUrl: (savedUrl != null && savedUrl.isNotEmpty) ? savedUrl : _defaultCobaltUrl,
      youtubeCookies: savedCookies ?? '',
    );
  }

  Future<void> setCobaltUrl(String url) async {
    // Normalizar la URL quitando barra diagonal final si la tiene
    String normalizedUrl = url.trim();
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    
    state = state.copyWith(cobaltUrl: normalizedUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cobaltUrlKey, normalizedUrl);
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
