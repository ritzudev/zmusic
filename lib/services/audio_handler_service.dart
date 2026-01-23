import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:home_widget/home_widget.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/services/local_server_service.dart';

/// Servicio de audio que maneja la reproducción en segundo plano
/// Integra just_audio con audio_service para controles en pantalla de bloqueo
class MusicAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final List<StreamSubscription> _subscriptions = [];
  SMTCWindows? _smtc;
  SharedPreferences? _prefs;

  // Motor de audio para Windows
  mk.Player? _mkPlayer;

  // Lista de reproducción actual
  List<MusicTrack> _playlist = [];
  List<MusicTrack> _originalPlaylist = []; // Playlist sin mezclar
  int _currentIndex = 0;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  bool _isShuffleEnabled = false;
  String? _placeholderPath;
  Uint8List? _placeholderBytes;

  MusicAudioHandler() {
    if (Platform.isWindows) {
      _mkPlayer = mk.Player();
      LocalServerService().start();
    }
    _init();
    _preparePlaceholder();
    if (Platform.isWindows) {
      _initSMTC();
    }
  }

  Future<void> _initSMTC() async {
    try {
      // Registrar el plugin
      await SMTCWindows.initialize();

      _smtc = SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
          fastForwardEnabled: true,
          rewindEnabled: true,
        ),
      );

      _smtc?.buttonPressStream.listen((event) async {
        switch (event) {
          case PressedButton.play:
            await play();
            break;
          case PressedButton.pause:
            await pause();
            break;
          case PressedButton.next:
            await skipToNext();
            break;
          case PressedButton.previous:
            await skipToPrevious();
            break;
          case PressedButton.stop:
            await stop();
            break;
          default:
            break;
        }
      });

      // Forzar estado inicial para que Windows habilite los botones
      await _smtc?.setPlaybackStatus(PlaybackStatus.paused);
    } catch (e) {
      print('Error al inicializar SMTC para Windows: $e');
    }
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
      // Cacheamos los bytes para el servidor de Windows
      _placeholderBytes = await file.readAsBytes();
    } catch (e) {
      print('Error al preparar placeholder de notificación: $e');
    }
  }

  void _init() {
    // Escuchar cambios en el estado de reproducción
    _subscriptions.add(
      _player.playbackEventStream.listen((event) {
        _broadcastState();
      }),
    );

    // Cargar volumen guardado
    _loadSavedVolume();

    // Escuchar cuando termina una canción
    _subscriptions.add(
      _player.processingStateStream.listen((state) {
        if (!Platform.isWindows && state == ProcessingState.completed) {
          _handleSongCompleted();
        }
      }),
    );

    // Escuchar cuando termina una canción en Media Kit (Windows)
    if (Platform.isWindows) {
      _mkPlayer?.stream.completed.listen((completed) {
        if (completed) {
          _handleSongCompleted();
        }
      });

      _mkPlayer?.stream.position.listen((position) {
        final oldState = playbackState.value;
        playbackState.add(oldState.copyWith(updatePosition: position));
      });

      _mkPlayer?.stream.duration.listen((duration) async {
        if (_currentIndex < _playlist.length) {
          final track = _playlist[_currentIndex];
          final artUri = await _getArtworkUri(track);

          // Actualizar AudioService (Interfaz Flutter)
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

          // Actualizar Windows SMTC (Barra de Windows)
          _updateSMTCMetadata();
          _updateSMTCTimeline();
        }
      });

      _mkPlayer?.stream.playing.listen((isPlaying) {
        _broadcastState();
        _updateSMTCTimeline(); // Sincronizar slider al pausar/reproducir
      });

      _mkPlayer?.stream.volume.listen((volume) {
        _broadcastState();
      });
    }

    // Escuchar cambios en la posición
    _subscriptions.add(
      _player.positionStream.listen((position) {
        final oldState = playbackState.value;
        playbackState.add(oldState.copyWith(updatePosition: position));
      }),
    );

    // Escuchar cambios en la duración
    _subscriptions.add(
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
      }),
    );
  }

  /// Obtener URI del artwork para la notificación
  Future<Uri?> _getArtworkUri(MusicTrack track) async {
    try {
      Uint8List? artworkBytes;

      if (Platform.isWindows) {
        // En Windows usamos audio_metadata_reader que SÍ está funcionando
        try {
          final file = File(track.filePath);
          final metadata = amr.readMetadata(file, getImage: true);
          if (metadata.pictures.isNotEmpty) {
            artworkBytes = metadata.pictures.first.bytes;
          }
        } catch (e) {
          // Error silencioso al extraer carátula
        }
      } else {
        // En móviles seguimos usando on_audio_query
        artworkBytes = await _audioQuery.queryArtwork(
          track.albumId ?? track.songId,
          track.albumId != null ? ArtworkType.ALBUM : ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 500,
        );
      }

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
        } else if (Platform.isWindows) {
          LocalServerService().updateArtwork(artworkBytes);
          final url = LocalServerService().artworkUrl;
          return url != null ? Uri.parse(url) : null;
        }
        return null;
      }

      if (Platform.isWindows) {
        // Usar placeholder cacheado en memoria para el servidor local
        if (_placeholderBytes != null) {
          LocalServerService().updateArtwork(
            _placeholderBytes,
            mimeType: 'image/png',
          );
          final url = LocalServerService().artworkUrl;
          return url != null ? Uri.parse(url) : null;
        } else {
          LocalServerService().updateArtwork(null);
        }
      }

      // Si no existe artwork real, usar el placeholder morado
      if (_placeholderPath != null) {
        return Uri.file(_placeholderPath!);
      }

      return null;
    } catch (e) {
      print('Error al verificar artwork para notificación: $e');

      if (Platform.isWindows && _placeholderBytes != null) {
        LocalServerService().updateArtwork(
          _placeholderBytes,
          mimeType: 'image/png',
        );
      }

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
        playing: Platform.isWindows
            ? (_mkPlayer?.state.playing ?? false)
            : _player.playing,
        updatePosition: Platform.isWindows
            ? (_mkPlayer?.state.position ?? Duration.zero)
            : _player.position,
        bufferedPosition: Platform.isWindows
            ? (_mkPlayer?.state.buffer ?? Duration.zero)
            : _player.bufferedPosition,
        speed: Platform.isWindows
            ? (_mkPlayer?.state.rate ?? 1.0)
            : _player.speed,
        queueIndex: _currentIndex,
        repeatMode: _repeatMode,
      ),
    );
    _updateHomeWidget();
    // En Windows, solo actualizamos el estado (play/pause), NO los metadatos.
    // Los metadatos los actualizamos solo cuando cambia la canción para no saturar al sistema.
    _updateSMTCStatusOnly();
    _updateTaskbar();
  }

  /// Actualizar SOLO el estado de reproducción de SMTC (play/pause)
  Future<void> _updateSMTCStatusOnly() async {
    if (!Platform.isWindows || _smtc == null) return;
    try {
      final isPlaying = _mkPlayer?.state.playing ?? false;
      // Actualizar estado de reproducción
      await _smtc?.setPlaybackStatus(
        isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
      );
    } catch (e) {
      print('Error al actualizar estado SMTC: $e');
    }
  }

  /// Actualizar la LÍNEA DE TIEMPO de Windows (Slider y posición)
  Future<void> _updateSMTCTimeline() async {
    if (!Platform.isWindows || _smtc == null) return;
    try {
      final state = _mkPlayer?.state;
      if (state != null) {
        await _smtc?.updateTimeline(
          PlaybackTimeline(
            startTimeMs: 0,
            endTimeMs: state.duration.inMilliseconds,
            positionMs: state.position.inMilliseconds,
          ),
        );
      }
    } catch (e) {
      print('Error al actualizar línea de tiempo SMTC: $e');
    }
  }

  /// Actualizar los METADATOS completos de SMTC (Título, artista, carátula)
  /// Solo se llama cuando cambia la canción.
  Future<void> _updateSMTCMetadata() async {
    if (!Platform.isWindows || _smtc == null) return;

    try {
      final track = currentTrack;
      if (track != null) {
        final artUri = await _getArtworkUri(track);
        // Convertimos a string para que maneje tanto file:// como http:// de nuestro servidor local
        String? finalThumbnail = artUri?.toString();

        await _smtc?.updateMetadata(
          MusicMetadata(
            title: track.title,
            artist: track.artist,
            album: track.album ?? 'Álbum Desconocido',
            thumbnail: finalThumbnail,
          ),
        );
      }
    } catch (e) {
      print('Error al actualizar metadatos SMTC: $e');
    }
  }

  /// Actualizar los botones de la barra de tareas en Windows
  Future<void> _updateTaskbar() async {
    if (!Platform.isWindows) return;

    try {
      final isPlaying = _mkPlayer?.state.playing ?? false;

      await WindowsTaskbar.setThumbnailToolbar([
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/back.ico'),
          'Anterior',
          () => skipToPrevious(),
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon(
            isPlaying ? 'assets/pause.ico' : 'assets/play.ico',
          ),
          isPlaying ? 'Pausar' : 'Reproducir',
          () => togglePlayPause(),
        ),
        ThumbnailToolbarButton(
          ThumbnailToolbarAssetIcon('assets/next.ico'),
          'Siguiente',
          () => skipToNext(),
        ),
      ]);
    } catch (e) {
      print('Error al actualizar barra de tareas: $e');
    }
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

    if (_isShuffleEnabled) {
      _playlist = List.from(tracks);
      _playlist.shuffle();

      // Si tenemos un índice inicial, buscar esa canción en la lista mezclada
      // para empezar por ella, si no, empezar desde el índice 0 de la lista mezclada.
      if (initialIndex >= 0 && initialIndex < tracks.length) {
        final targetTrack = tracks[initialIndex];
        _currentIndex = _playlist.indexWhere((t) => t.id == targetTrack.id);
        if (_currentIndex == -1) _currentIndex = 0;
      } else {
        _currentIndex = 0;
      }
    } else {
      _playlist = List.from(tracks);
      _currentIndex = initialIndex;
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
      if (Platform.isWindows) {
        await _mkPlayer?.open(mk.Media(track.filePath));
      } else {
        final uri = Uri.file(track.filePath);
        await _player.setAudioSource(
          AudioSource.uri(uri),
          initialPosition: Duration.zero,
          preload: true,
        );
      }

      // En Windows, actualizamos metadatos pesados (imagen) solo al cargar la pista
      if (Platform.isWindows) {
        _updateSMTCMetadata();
      }

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
    } catch (_) {}
  }

  /// Reproducir una canción específica de la lista
  Future<void> playTrack(int index) async {
    await _loadTrack(index);
    await play();
  }

  @override
  Future<void> play() async {
    try {
      if (Platform.isWindows) {
        await _mkPlayer?.play();
      } else {
        await _player.play();
      }
      _broadcastState();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    if (Platform.isWindows) {
      await _mkPlayer?.pause();
    } else {
      await _player.pause();
    }
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    if (Platform.isWindows) {
      await _mkPlayer?.stop();
    } else {
      await _player.stop();
      await _player.seek(Duration.zero);
    }
    _broadcastState();
  }

  @override
  Future<void> seek(Duration position) async {
    if (Platform.isWindows) {
      await _mkPlayer?.seek(position);
    } else {
      await _player.seek(position);
    }
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
    final isPlaying = Platform.isWindows
        ? (_mkPlayer?.state.playing ?? false)
        : _player.playing;

    if (isPlaying) {
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
  Stream<Duration> get positionStream => Platform.isWindows
      ? (_mkPlayer?.stream.position ?? const Stream.empty())
      : _player.positionStream;

  /// Stream de la duración
  Stream<Duration?> get durationStream => Platform.isWindows
      ? (_mkPlayer?.stream.duration ?? const Stream.empty())
      : _player.durationStream;

  /// Stream del estado de reproducción
  Stream<bool> get playingStream => Platform.isWindows
      ? (_mkPlayer?.stream.playing ?? const Stream.empty())
      : _player.playingStream;

  /// Stream del volumen (mapeado de 0-150 a 0.0-1.0 para el Slider)
  Stream<double> get volumeStream => Platform.isWindows
      ? (_mkPlayer?.stream.volume.map((v) => (v / 115).clamp(0.0, 1.0)) ??
            const Stream.empty())
      : _player.volumeStream;

  /// Establecer el volumen (0.0 a 1.0)
  Future<void> setVolume(double volume) async {
    if (Platform.isWindows) {
      // Aplicamos un boost del 50% (multiplicamos por 150 en lugar de 100)
      await _mkPlayer?.setVolume(volume * 115);
    } else {
      await _player.setVolume(volume);
    }

    // Guardar volumen en preferencias
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setDouble('player_volume', volume);
  }

  /// Cargar el volumen guardado en preferencias
  Future<void> _loadSavedVolume() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedVolume = _prefs?.getDouble('player_volume');
      if (savedVolume != null) {
        if (Platform.isWindows) {
          await _mkPlayer?.setVolume(
            savedVolume * 115,
          ); // Mismo multiplicador de boost
        } else {
          await _player.setVolume(savedVolume);
        }
      }
    } catch (e) {
      print('Error al cargar volumen guardado: $e');
    }
  }

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
    // Cancelar todas las suscripciones primero
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    // Liberar SMTC si existe
    try {
      if (_smtc != null) {
        _smtc?.dispose();
        _smtc = null;
      }
      if (Platform.isWindows) {
        await LocalServerService().stop();
      }
    } catch (e) {
      print('Error al liberar SMTC: $e');
    }

    // Detener y liberar el reproductor de forma segura
    try {
      if (_player.playing) {
        await _player.stop();
      }
      await _player.dispose();

      if (_mkPlayer != null) {
        await _mkPlayer?.stop();
        await _mkPlayer?.dispose();
        _mkPlayer = null;
      }
    } catch (e) {
      print('Error al liberar el reproductor: $e');
    }
  }
}
