import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:home_widget/home_widget.dart';
import 'package:zmusic/models/song_model.dart';

/// Servicio de audio que maneja la reproducción en segundo plano
/// Integra just_audio con audio_service para controles en pantalla de bloqueo
class MusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // Lista de reproducción actual
  List<MusicTrack> _playlist = [];
  List<MusicTrack> _originalPlaylist = []; // Playlist sin mezclar
  int _currentIndex = 0;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  bool _isShuffleEnabled = false;
  String? _placeholderPath;

  MusicAudioHandler() {
    _init();
    _preparePlaceholder();
  }

  Future<void> _preparePlaceholder() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/notification_placeholder.png';
      final file = File(path);

      if (!await file.exists()) {
        final byteData = await rootBundle.load(
          'assets/notification_placeholder.png',
        );
        await file.writeAsBytes(byteData.buffer.asUint8List());
      }
      _placeholderPath = path;
    } catch (e) {
      print('Error al preparar placeholder de notificación: $e');
    }
  }

  void _init() {
    // Escuchar cambios en el estado de reproducción
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Escuchar cuando termina una canción
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleSongCompleted();
      }
    });

    // Escuchar cambios en la posición
    _player.positionStream.listen((position) {
      final oldState = playbackState.value;
      playbackState.add(oldState.copyWith(updatePosition: position));
    });

    // Escuchar cambios en la duración
    _player.durationStream.listen((duration) async {
      if (duration != null && _currentIndex < _playlist.length) {
        final track = _playlist[_currentIndex];
        final artUri = await _getArtworkUri(track);
        mediaItem.add(
          MediaItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? 'Álbum Desconocido',
            duration: duration,
            artUri: artUri,
          ),
        );
      }
    });
  }

  /// Obtener URI del artwork para la notificación
  Future<Uri?> _getArtworkUri(MusicTrack track) async {
    try {
      Uint8List? artworkBytes;

      // Solo consultar artwork via MediaStore/OnAudioQuery en móviles
      if (Platform.isAndroid || Platform.isIOS) {
        artworkBytes = await _audioQuery.queryArtwork(
          track.albumId ?? track.songId,
          track.albumId != null ? ArtworkType.ALBUM : ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 200, // Tamaño pequeño solo para verificación rápida
        );
      }

      // Si existe artwork (bytes no nulos y no vacíos)
      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        if (Platform.isAndroid) {
          if (track.albumId != null) {
            return Uri.parse(
              'content://media/external/audio/albumart/${track.albumId}',
            );
          } else {
            return Uri.parse(
              'content://media/external/audio/media/${track.songId}/albumart',
            );
          }
        } else {
          // Para Windows/otros, guardar a archivo temporal y devolver uri de archivo
          final directory = await getTemporaryDirectory();
          final artworkPath =
              '${directory.path}/thumb_${track.id.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.jpg';
          final file = File(artworkPath);
          if (!await file.exists()) {
            await file.writeAsBytes(artworkBytes);
          }
          return Uri.file(artworkPath);
        }
      }

      // Si no existe artwork real, usar el placeholder morado
      if (_placeholderPath != null) {
        return Uri.file(_placeholderPath!);
      }

      return null;
    } catch (e) {
      print('Error al verificar artwork para notificación: $e');
      // Fallback al placeholder en caso de error
      if (_placeholderPath != null) {
        return Uri.file(_placeholderPath!);
      }
      return null;
    }
  }

  /// Manejar cuando una canción termina
  Future<void> _handleSongCompleted() async {
    switch (_repeatMode) {
      case AudioServiceRepeatMode.one:
        // Repetir la canción actual
        await seek(Duration.zero);
        await play();
        break;
      case AudioServiceRepeatMode.all:
        // Ir a la siguiente canción (o volver al inicio)
        await skipToNext();
        break;
      case AudioServiceRepeatMode.none:
        // Solo ir a la siguiente si no es la última
        if (_currentIndex < _playlist.length - 1) {
          await skipToNext();
        } else {
          // Detener al final de la playlist
          await stop();
        }
        break;
      case AudioServiceRepeatMode.group:
        // No usamos este modo, pero lo manejamos igual que 'all'
        await skipToNext();
        break;
    }
  }

  /// Transmitir el estado actual de reproducción
  void _broadcastState() {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          //MediaControl.stop,
          MediaControl.rewind,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        // Índices de botones que aparecen cuando la notificación es pequeña (compacta)
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
        repeatMode: _repeatMode,
      ),
    );
    _updateHomeWidget();
  }

  /// Actualizar el Home Widget con los datos actuales
  Future<void> _updateHomeWidget() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final track = currentTrack;
    if (track == null) return;

    await HomeWidget.saveWidgetData<String>('title', track.title);
    await HomeWidget.saveWidgetData<String>('artist', track.artist);
    await HomeWidget.saveWidgetData<bool>('is_playing', _player.playing);

    // Guardar carátula para el widget
    try {
      final artworkBytes = await _audioQuery.queryArtwork(
        track.albumId ?? track.songId,
        track.albumId != null ? ArtworkType.ALBUM : ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 500,
      );

      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        final directory = await getTemporaryDirectory();
        final artworkPath = '${directory.path}/widget_artwork.jpg';
        final file = File(artworkPath);
        await file.writeAsBytes(artworkBytes);
        await HomeWidget.saveWidgetData<String>('artwork_path', artworkPath);
      } else {
        await HomeWidget.saveWidgetData<String>('artwork_path', null);
      }
    } catch (e) {
      print('Error al guardar artwork para el widget: $e');
    }

    await HomeWidget.updateWidget(
      name: 'HomeScreenWidgetProvider',
      androidName: 'HomeScreenWidgetProvider',
    );
  }

  /// Establecer la lista de reproducción
  Future<void> setPlaylist(
    List<MusicTrack> tracks, {
    int initialIndex = 0,
    bool playImmediately = false,
  }) async {
    _originalPlaylist = List.from(tracks); // Guardar orden original
    _playlist = List.from(tracks);
    _currentIndex = initialIndex;

    // Actualizar la cola
    queue.add(
      _playlist
          .map(
            (track) => MediaItem(
              id: track.id,
              title: track.title,
              artist: track.artist,
              album: track.album ?? 'Álbum Desconocido',
              duration: track.duration,
              artUri: track.albumArt != null
                  ? Uri.parse(track.albumArt!)
                  : null,
            ),
          )
          .toList(),
    );

    if (_playlist.isNotEmpty) {
      await _loadTrack(_currentIndex);
      if (playImmediately) {
        await play();
      }
    }
  }

  /// Cargar una pista específica
  Future<void> _loadTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    final track = _playlist[index];

    try {
      print('DEBUG_PLAY: Seteando ruta en el player: ${track.filePath}');

      final uri = Uri.file(track.filePath);
      print('DEBUG_PLAY: URI generado: ${uri.toString()}');

      // En Windows, setAudioSource a veces no dispara el inicio de la reproducción correctamente
      // si se llama inmediatamente a play(). Asegurarse de que el source se establezca bien.
      await _player.setAudioSource(
        AudioSource.uri(uri),
        initialPosition: Duration.zero,
        preload: true,
      );

      // En Windows, a veces es útil llamar a load() explícitamente después de setAudioSource
      // o simplemente esperar a que el estado sea 'ready'.
      if (Platform.isWindows) {
        print(
          'DEBUG_PLAY: Esperando a que el player esté cargado (Windows)...',
        );
        await _player.load();
      }

      print('DEBUG_PLAY: Archivo cargado satisfactoriamente.');

      // Intentar obtener el artwork de forma segura
      try {
        final artUri = await _getArtworkUri(track);
        mediaItem.add(
          MediaItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? 'Álbum Desconocido',
            duration: track.duration ?? _player.duration,
            artUri: artUri,
          ),
        );
      } catch (artworkError) {
        print('DEBUG_PLAY: Error (no fatal) al cargar artwork: $artworkError');
        // Continuar sin artwork
        mediaItem.add(
          MediaItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? 'Álbum Desconocido',
            duration: track.duration ?? _player.duration,
          ),
        );
      }

      _broadcastState();
    } catch (e, stack) {
      print('DEBUG_PLAY: ERROR CRÍTICO al cargar la pista: $e');
      print('DEBUG_PLAY: StackTrace: $stack');
    }
  }

  /// Reproducir una canción específica de la lista
  Future<void> playTrack(int index) async {
    await _loadTrack(index);
    await play();
  }

  @override
  Future<void> play() async {
    try {
      print('DEBUG_PLAY: Llamando a _player.play()');

      // En Windows, a veces la transición de loading a playing falla si es muy rápida
      if (Platform.isWindows) {
        // Esperar un momento corto para asegurar que el estado se estabilice
        await Future.delayed(const Duration(milliseconds: 100));

        // Si aún está cargando, esperar un poco más o delegar al stream
        if (_player.processingState == ProcessingState.loading ||
            _player.processingState == ProcessingState.buffering) {
          print(
            'DEBUG_PLAY: Player aún cargando, esperando a que esté listo...',
          );
          // Opcional: podrías esperar al stream, pero play() ya debería manejarlo internamente.
          // Sin embargo, en Windows a veces necesita un empujón extra.
        }
      }

      await _player.play();
      _broadcastState();
      print(
        'DEBUG_PLAY: _player.play() ejecutado con éxito. playing=${_player.playing}',
      );
    } catch (e) {
      print('DEBUG_PLAY: Error en play(): $e');
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.seek(Duration.zero);
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> rewind() async {
    final newPosition = _player.position - const Duration(seconds: 10);
    await _player.seek(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
    _broadcastState();
  }

  @override
  Future<void> fastForward() async {
    final duration = _player.duration ?? Duration.zero;
    final newPosition = _player.position + const Duration(seconds: 10);
    await _player.seek(newPosition > duration ? duration : newPosition);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    if (_currentIndex < _playlist.length - 1) {
      await playTrack(_currentIndex + 1);
    } else {
      // Volver al inicio si estamos en la última canción
      await playTrack(0);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      // Si llevamos más de 3 segundos, reiniciar la canción actual
      await seek(Duration.zero);
    } else if (_currentIndex > 0) {
      // Si no, ir a la canción anterior
      await playTrack(_currentIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await playTrack(index);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  /// Alternar reproducción/pausa
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Obtener la pista actual
  MusicTrack? get currentTrack {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      return _playlist[_currentIndex];
    }
    return null;
  }

  /// Obtener el índice actual
  int get currentIndex => _currentIndex;

  /// Obtener la lista de reproducción
  List<MusicTrack> get playlist => _playlist;

  /// Stream de la posición actual
  Stream<Duration> get positionStream => _player.positionStream;

  /// Stream de la duración
  Stream<Duration?> get durationStream => _player.durationStream;

  /// Stream del estado de reproducción
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> onTaskRemoved() async {
    // NO detener la reproducción cuando se cierra la app desde recientes
    // Solo pausar si no está reproduciendo
    // Esto permite que la música continúe en segundo plano
    // El usuario puede detenerla desde la notificación si lo desea
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    // Si el modo que llega es el mismo que el actual, asumimos que se pulsó
    // el botón de la notificación y queremos "ciclar" al siguiente modo.
    // Esto es un truco común cuando el botón de la notificación no envía el siguiente estado.
    if (repeatMode == _repeatMode) {
      switch (_repeatMode) {
        case AudioServiceRepeatMode.none:
          _repeatMode = AudioServiceRepeatMode.all;
          break;
        case AudioServiceRepeatMode.all:
          _repeatMode = AudioServiceRepeatMode.one;
          break;
        case AudioServiceRepeatMode.one:
          _repeatMode = AudioServiceRepeatMode.none;
          break;
        default:
          _repeatMode = AudioServiceRepeatMode.none;
      }
    } else {
      _repeatMode = repeatMode;
    }

    _broadcastState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _isShuffleEnabled = shuffleMode == AudioServiceShuffleMode.all;

    if (_isShuffleEnabled) {
      // Guardar la canción actual
      final currentTrack = _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

      // Mezclar la playlist
      _playlist = List.from(_originalPlaylist);
      _playlist.shuffle();

      // Encontrar la canción actual en la nueva lista mezclada
      if (currentTrack != null) {
        _currentIndex = _playlist.indexWhere(
          (track) => track.id == currentTrack.id,
        );
        if (_currentIndex == -1) _currentIndex = 0;
      }
    } else {
      // Restaurar orden original
      final currentTrack = _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

      _playlist = List.from(_originalPlaylist);

      // Encontrar la canción actual en la lista original
      if (currentTrack != null) {
        _currentIndex = _playlist.indexWhere(
          (track) => track.id == currentTrack.id,
        );
        if (_currentIndex == -1) _currentIndex = 0;
      }
    }

    // Actualizar la cola
    queue.add(
      _playlist
          .map(
            (track) => MediaItem(
              id: track.id,
              title: track.title,
              artist: track.artist,
              album: track.album ?? 'Álbum Desconocido',
              duration: track.duration,
              artUri: track.albumArt != null
                  ? Uri.parse(track.albumArt!)
                  : null,
            ),
          )
          .toList(),
    );

    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  /// Liberar recursos
  Future<void> dispose() async {
    await _player.dispose();
  }
}
