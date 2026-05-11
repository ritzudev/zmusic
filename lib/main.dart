import 'dart:io';
import 'package:flutter/material.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:flutter/services.dart';
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
import 'package:media_kit/media_kit.dart';
import 'package:zmusic/services/window_service.dart';
import 'package:zmusic/services/typing_state.dart';

@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  debugPrint('TAG_DEBUG: [Widget Background Action] $uri');
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      "com.ritzu.zmusic",
      onSecondWindow: (args) {
        WindowService().showWindow();
      },
    );
    MediaKit.ensureInitialized();
    await WindowService().init();
  }

  // HomeWidget es solo para Android e iOS
  if (Platform.isAndroid || Platform.isIOS) {
    HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  }

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
    if (Platform.isAndroid || Platform.isIOS) {
      _setupHomeWidgetListener();
    }
    if (Platform.isWindows) {
      // Necesitamos esperar al siguiente frame para tener acceso a ref
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupHotkeys();
      });
    }
  }

  void _setupHotkeys() {
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    HardwareKeyboard.instance.addHandler((KeyEvent event) {
      // Solo nos interesan los eventos cuando se PRESIONA la tecla
      if (event is! KeyDownEvent) return false;

      // Si está escribiendo (validado a través de TypingState desde el TextField),
      // DEJAMOS PASAR la tecla para que se escriba (retornamos false)
      if (TypingState.isTyping) {
        return false;
      }

      // Si NO está escribiendo, evaluamos qué tecla presionó
      if (event.logicalKey == LogicalKeyboardKey.space) {
        playerNotifier.togglePlayPause();
        return true; // Retornar true significa que interceptamos la tecla (no hace nada más)
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        playerNotifier.skipToNext();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        playerNotifier.skipToPrevious();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        playerNotifier.toggleShuffle();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
        playerNotifier.toggleRepeatMode();
        return true;
      }

      // Para cualquier otra tecla, simplemente no hacemos nada
      return false;
    });
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
