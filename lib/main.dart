import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/theme_provider.dart';
import 'package:zmusic/screens/music_home_screen.dart';
import 'package:zmusic/screens/now_playing_screen.dart';
import 'package:zmusic/screens/settings_screen.dart';
import 'package:zmusic/screens/tagger_test_screen.dart';
import 'package:zmusic/screens/youtube_search_screen.dart';
import 'package:zmusic/theme/app_theme.dart';
import 'package:home_widget/home_widget.dart';
import 'package:zmusic/providers/audio_player_provider.dart';

@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  debugPrint('TAG_DEBUG: [Widget Background Action] $uri');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  @override
  void initState() {
    super.initState();
    _setupHomeWidgetListener();
  }

  void _setupHomeWidgetListener() {
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri == null) {
        debugPrint('TAG_DEBUG: [UI Listener] Recibido URI nulo');
        return;
      }

      debugPrint('TAG_DEBUG: [UI Listener] URI completo: $uri');

      final player = ref.read(audioPlayerProvider.notifier);
      final action = uri.host.isNotEmpty
          ? uri.host
          : uri.path.replaceAll('/', '');

      debugPrint('TAG_DEBUG: [UI Listener] Ejecutando acción: $action');

      switch (action) {
        case 'PLAY_PAUSE':
          debugPrint('TAG_DEBUG: [UI Listener] Llamando a togglePlayPause...');
          player.togglePlayPause();
          break;
        case 'SKIP_NEXT':
          debugPrint('TAG_DEBUG: [UI Listener] Llamando a skipToNext...');
          player.skipToNext();
          break;
        case 'SKIP_PREV':
          debugPrint('TAG_DEBUG: [UI Listener] Llamando a skipToPrevious...');
          player.skipToPrevious();
          break;
        default:
          debugPrint('TAG_DEBUG: [UI Listener] Acción desconocida: $action');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      theme: AppTheme.lightWithPalette(themeState.palette),
      darkTheme: AppTheme.darkWithPalette(themeState.palette),
      themeMode: themeState.mode,
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
