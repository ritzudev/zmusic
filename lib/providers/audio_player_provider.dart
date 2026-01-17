import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/services/audio_handler_service.dart';
import 'package:zmusic/models/repeat_mode.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/widgets/artwork_widget.dart';

part 'audio_player_provider.g.dart';

/// Provider del AudioHandler
@Riverpod(keepAlive: true)
Future<MusicAudioHandler> audioHandler(Ref ref) async {
  final handler = await AudioService.init(
    builder: () => MusicAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.zmusic.audio',
      androidNotificationChannelName: 'ZMusic Playback',
      androidNotificationChannelDescription:
          'Controles de reproducción de música',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidStopForegroundOnPause: true,
      androidNotificationClickStartsActivity: true,
      preloadArtwork: true,
      artDownscaleWidth: 256,
      artDownscaleHeight: 256,
      fastForwardInterval: const Duration(seconds: 10),
      rewindInterval: const Duration(seconds: 10),
    ),
  );

  // Limpiar cuando el provider se destruya
  ref.onDispose(() {
    handler.dispose();
  });

  return handler;
}

/// Estado del reproductor de música
class AudioPlayerState {
  final MusicTrack? currentTrack;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final List<MusicTrack> playlist;
  final int currentIndex;
  final bool isLoading;
  final RepeatMode repeatMode;
  final bool isShuffleEnabled;

  const AudioPlayerState({
    this.currentTrack,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.playlist = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.repeatMode = RepeatMode.none,
    this.isShuffleEnabled = false,
  });

  AudioPlayerState copyWith({
    MusicTrack? currentTrack,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<MusicTrack>? playlist,
    int? currentIndex,
    bool? isLoading,
    RepeatMode? repeatMode,
    bool? isShuffleEnabled,
  }) {
    return AudioPlayerState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      repeatMode: repeatMode ?? this.repeatMode,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
    );
  }

  /// Progreso de reproducción (0.0 a 1.0)
  double get progress {
    if (duration == null || duration!.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration!.inMilliseconds;
  }

  /// Tiempo restante
  Duration get remainingTime {
    if (duration == null) return Duration.zero;
    return duration! - position;
  }
}

/// Provider del estado del reproductor
@Riverpod(keepAlive: true)
class AudioPlayer extends _$AudioPlayer {
  MusicAudioHandler? _handler;

  // Subscripciones a los streams para poder cancelarlas
  final List<StreamSubscription> _subscriptions = [];

  // Completer para rastrear cuando el handler esté listo
  Completer<void>? _handlerReadyCompleter;

  @override
  AudioPlayerState build() {
    // Inicializar el completer
    _handlerReadyCompleter = Completer<void>();

    // Inicializar el handler de forma asíncrona
    _initHandler();

    // Limpiar subscripciones cuando el provider se destruya
    ref.onDispose(() {
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();
      _handlerReadyCompleter = null;
    });

    return const AudioPlayerState();
  }

  Future<void> _initHandler() async {
    try {
      _handler = await ref.watch(audioHandlerProvider.future);

      // Escuchar cambios en el estado de reproducción
      final playingSub = _handler!.playingStream.listen((isPlaying) {
        state = state.copyWith(isPlaying: isPlaying);
      });
      _subscriptions.add(playingSub);

      // Escuchar cambios en la posición
      final positionSub = _handler!.positionStream.listen((position) {
        state = state.copyWith(position: position);
      });
      _subscriptions.add(positionSub);

      // Escuchar cambios en la duración
      final durationSub = _handler!.durationStream.listen((duration) {
        state = state.copyWith(duration: duration);
      });
      _subscriptions.add(durationSub);

      // Escuchar cambios en el mediaItem
      final mediaItemSub = _handler!.mediaItem.listen((mediaItem) {
        if (mediaItem != null && _handler!.currentTrack != null) {
          state = state.copyWith(
            currentTrack: _handler!.currentTrack,
            currentIndex: _handler!.currentIndex,
          );

          // Pre-cachear el artwork de la siguiente canción
          _preCacheNextArtwork();
        }
      });
      _subscriptions.add(mediaItemSub);

      // Marcar el handler como listo
      if (_handlerReadyCompleter != null &&
          !_handlerReadyCompleter!.isCompleted) {
        _handlerReadyCompleter!.complete();
      }
    } catch (e) {
      // Manejar error de inicialización
      print('Error al inicializar el audio handler: $e');
      if (_handlerReadyCompleter != null &&
          !_handlerReadyCompleter!.isCompleted) {
        _handlerReadyCompleter!.completeError(e);
      }
    }
  }

  /// Pre-cachear el artwork de la siguiente canción
  void _preCacheNextArtwork() {
    if (state.playlist.isEmpty) return;

    final nextIndex = (state.currentIndex + 1) % state.playlist.length;
    final nextTrack = state.playlist[nextIndex];

    // Disparar la carga del artwork para que esté en memoria cuando se necesite
    ref.read(
      artworkProvider((
        id: nextTrack.albumId ?? nextTrack.songId,
        type: nextTrack.albumId != null ? ArtworkType.ALBUM : ArtworkType.AUDIO,
      )).future,
    );
  }

  /// Esperar a que el handler esté listo
  Future<void> _ensureHandlerReady() async {
    if (_handler == null) {
      // Esperar a que el completer se complete
      if (_handlerReadyCompleter != null) {
        await _handlerReadyCompleter!.future;
      }

      // Verificar nuevamente
      if (_handler == null) {
        throw Exception('Audio handler no está inicializado');
      }
    }
  }

  /// Establecer la lista de reproducción y reproducir
  Future<void> setPlaylistAndPlay(
    List<MusicTrack> tracks, {
    int initialIndex = 0,
  }) async {
    try {
      await _ensureHandlerReady();

      state = state.copyWith(isLoading: true);

      await _handler!.setPlaylist(tracks, initialIndex: initialIndex);

      state = state.copyWith(
        playlist: tracks,
        currentIndex: initialIndex,
        currentTrack: tracks.isNotEmpty ? tracks[initialIndex] : null,
        isLoading: false,
      );

      await _handler!.play();
    } catch (e) {
      print('Error al establecer playlist: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Reproducir una canción específica
  Future<void> playTrack(int index) async {
    try {
      await _ensureHandlerReady();
      await _handler!.playTrack(index);
    } catch (e) {
      print('Error al reproducir canción: $e');
    }
  }

  /// Reproducir
  Future<void> play() async {
    try {
      await _ensureHandlerReady();
      await _handler!.play();
    } catch (e) {
      print('Error al reproducir: $e');
    }
  }

  /// Pausar
  Future<void> pause() async {
    try {
      await _ensureHandlerReady();
      await _handler!.pause();
    } catch (e) {
      print('Error al pausar: $e');
    }
  }

  /// Alternar play/pause
  Future<void> togglePlayPause() async {
    try {
      await _ensureHandlerReady();
      await _handler!.togglePlayPause();
    } catch (e) {
      print('Error al alternar play/pause: $e');
    }
  }

  /// Siguiente canción
  Future<void> skipToNext() async {
    try {
      await _ensureHandlerReady();
      await _handler!.skipToNext();
    } catch (e) {
      print('Error al saltar a siguiente: $e');
    }
  }

  /// Canción anterior
  Future<void> skipToPrevious() async {
    try {
      await _ensureHandlerReady();
      await _handler!.skipToPrevious();
    } catch (e) {
      print('Error al saltar a anterior: $e');
    }
  }

  /// Buscar posición
  Future<void> seek(Duration position) async {
    try {
      await _ensureHandlerReady();
      await _handler!.seek(position);
    } catch (e) {
      print('Error al buscar posición: $e');
    }
  }

  /// Detener reproducción
  Future<void> stop() async {
    try {
      await _ensureHandlerReady();
      await _handler!.stop();
      state = const AudioPlayerState();
    } catch (e) {
      print('Error al detener: $e');
    }
  }

  /// Alternar modo de repetición
  Future<void> toggleRepeatMode() async {
    try {
      await _ensureHandlerReady();

      // Obtener el siguiente modo
      final newMode = state.repeatMode.next;

      // Actualizar el estado local
      state = state.copyWith(repeatMode: newMode);

      // Configurar en el audio handler (convertir a AudioServiceRepeatMode)
      await _handler!.setRepeatMode(newMode.toAudioServiceMode());
    } catch (e) {
      print('Error al alternar modo de repetición: $e');
    }
  }

  /// Alternar modo aleatorio (shuffle)
  Future<void> toggleShuffle() async {
    try {
      await _ensureHandlerReady();

      // Alternar el estado
      final newShuffleState = !state.isShuffleEnabled;

      // Actualizar el estado local
      state = state.copyWith(isShuffleEnabled: newShuffleState);

      // Configurar en el audio handler
      final shuffleMode = newShuffleState
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none;
      await _handler!.setShuffleMode(shuffleMode);
    } catch (e) {
      print('Error al alternar modo aleatorio: $e');
    }
  }
}
