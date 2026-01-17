import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/theme_provider.dart';
import 'package:zmusic/screens/music_home_screen.dart';
import 'package:zmusic/screens/now_playing_screen.dart';
import 'package:zmusic/screens/settings_screen.dart';
import 'package:zmusic/screens/tagger_test_screen.dart';
import 'package:zmusic/screens/youtube_search_screen.dart';
import 'package:zmusic/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const MusicHomeScreen(),
      routes: {
        '/now-playing': (context) => const NowPlayingScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/youtube-search': (context) => const YouTubeSearchScreen(),
        '/tagger-test': (context) => const TaggerTestApp(),
      },
    );
  }
}
