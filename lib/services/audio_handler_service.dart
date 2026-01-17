import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zmusic/models/song_model.dart';

/// Servicio de audio que maneja la reproducción en segundo plano
/// Integra just_audio con audio_service para controles en pantalla de bloqueo
class MusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  // Lista de reproducción actual
  List<MusicTrack> _playlist = [];
  List<MusicTrack> _originalPlaylist = []; // Playlist sin mezclar
  int _currentIndex = 0;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  bool _isShuffleEnabled = false;

  MusicAudioHandler() {
    _init();
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
    _player.durationStream.listen((duration) {
      if (duration != null && _currentIndex < _playlist.length) {
        final track = _playlist[_currentIndex];
        mediaItem.add(
          MediaItem(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album ?? 'Álbum Desconocido',
            duration: duration,
            artUri: track.albumArt != null ? Uri.parse(track.albumArt!) : null,
          ),
        );
      }
    });
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
  }

  /// Establecer la lista de reproducción
  Future<void> setPlaylist(
    List<MusicTrack> tracks, {
    int initialIndex = 0,
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
    }
  }

  /// Cargar una pista específica
  Future<void> _loadTrack(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    _currentIndex = index;
    final track = _playlist[index];

    try {
      await _player.setFilePath(track.filePath);

      mediaItem.add(
        MediaItem(
          id: track.id,
          title: track.title,
          artist: track.artist,
          album: track.album ?? 'Álbum Desconocido',
          duration: track.duration ?? _player.duration,
          artUri: track.albumArt != null ? Uri.parse(track.albumArt!) : null,
        ),
      );

      _broadcastState();
    } catch (e) {
      print('Error al cargar la pista: $e');
    }
  }

  /// Reproducir una canción específica de la lista
  Future<void> playTrack(int index) async {
    await _loadTrack(index);
    await play();
  }

  @override
  Future<void> play() async {
    await _player.play();
    _broadcastState();
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
