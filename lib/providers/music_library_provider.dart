import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:path_provider/path_provider.dart';

part 'music_library_provider.g.dart';

@riverpod
class MusicLibrary extends _$MusicLibrary {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  static const String _cacheKey = 'music_library_cache';
  static const String _lastScanKey = 'last_scan_timestamp';
  static const String _customFolderKey = 'custom_music_folder';

  @override
  List<MusicTrack> build() {
    // Cargar desde caché al inicializar
    _loadFromCache();
    return [];
  }

  // Cargar biblioteca desde caché
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);

      if (cachedData != null && cachedData.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(cachedData);
        final songs = jsonList
            .map((json) => MusicTrack.fromJson(json))
            .toList();
        state = songs;
      }
    } catch (e) {
      // Si hay error al cargar caché, simplemente no hacer nada
      print('Error al cargar caché: $e');
    }
  }

  // Guardar biblioteca en caché
  Future<void> _saveToCache(List<MusicTrack> songs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = songs.map((song) => song.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error al guardar caché: $e');
    }
  }

  // Verificar si hay datos en caché
  Future<bool> hasCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      return cachedData != null && cachedData.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Obtener fecha del último escaneo
  Future<DateTime?> getLastScanDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastScanKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print('Error al obtener fecha de último escaneo: $e');
    }
    return null;
  }

  // Limpiar caché
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastScanKey);
    } catch (e) {
      print('Error al limpiar caché: $e');
    }
  }

  Future<bool> requestStoragePermission() async {
    print('DEBUG_PERM: Iniciando verificación de permisos...');
    if (Platform.isAndroid) {
      // Para Android 13+ (API 33+)
      final audioStatus = await Permission.audio.status;
      final photosStatus = await Permission.photos.status;
      print(
        'DEBUG_PERM: Estado actual - Audio: $audioStatus, Photos: $photosStatus',
      );

      if (audioStatus.isGranted && photosStatus.isGranted) {
        print('DEBUG_PERM: Permisos ya concedidos (Android 13+)');
        return true;
      }

      print('DEBUG_PERM: Solicitando permisos específicos de Android 13+...');
      final status = await [Permission.audio, Permission.photos].request();
      print(
        'DEBUG_PERM: Resultado solicitud - Audio: ${status[Permission.audio]}, Photos: ${status[Permission.photos]}',
      );

      if (status[Permission.audio] == PermissionStatus.granted) {
        return true;
      }

      // Para versiones anteriores de Android (12 o menor)
      final storageStatus = await Permission.storage.status;
      print('DEBUG_PERM: Estado actual Storage (Android < 13): $storageStatus');

      if (storageStatus.isGranted) {
        print('DEBUG_PERM: Permiso de Storage ya concedido');
        return true;
      }

      print('DEBUG_PERM: Solicitando permiso de Storage general...');
      final result = await Permission.storage.request();
      print('DEBUG_PERM: Resultado solicitud Storage: $result');
      return result.isGranted;
    }
    return true;
  }

  // Escanear automáticamente toda la música del dispositivo (como Samsung Music)
  Future<String> scanDeviceMusic() async {
    try {
      // Primero intentar con permission_handler
      bool hasPermission = await requestStoragePermission();

      if (!hasPermission) {
        // Si permission_handler dice que no, intentar con el plugin
        hasPermission = await _audioQuery.checkAndRequest(retryRequest: true);

        if (!hasPermission) {
          return 'Permisos denegados. Por favor, habilita los permisos en la configuración de la app.';
        }
      }

      // Pequeña pausa para asegurar que los permisos se aplicaron
      await Future.delayed(const Duration(milliseconds: 500));

      // Escanear todas las canciones del dispositivo
      final List<MusicTrack> songs = await querySongs();

      state = songs;

      // Guardar en caché
      await _saveToCache(songs);

      return '${songs.length} canción(es) encontrada(s)';
    } catch (e) {
      return 'Error al escanear música: $e';
    }
  }

  // Consultar todas las canciones usando on_audio_query_pluse o escaneo manual
  Future<List<MusicTrack>> querySongs() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final List<MusicTrack> songs = [];
        final audioSongs = await _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        for (var audioSong in audioSongs) {
          if (!_isMusicFile(audioSong)) continue;

          songs.add(
            MusicTrack(
              id: audioSong.id.toString(),
              songId: audioSong.id,
              albumId: audioSong.albumId,
              title: audioSong.title,
              artist: audioSong.artist ?? 'Artista Desconocido',
              filePath: audioSong.data,
              duration: Duration(milliseconds: audioSong.duration ?? 0),
              album: audioSong.album,
              size: audioSong.size,
            ),
          );
        }
        return songs;
      } else {
        // Windows/Desktop
        return await _manualScanWindows();
      }
    } catch (e) {
      print('Error en querySongs: $e');
      return [];
    }
  }

  // Escaneo manual para plataformas que no soportan on_audio_query (Windows)
  Future<List<MusicTrack>> _manualScanWindows() async {
    final List<MusicTrack> results = [];
    final List<String> pathsToScan = [];

    try {
      // 1. Obtener carpeta personalizada si existe
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString(_customFolderKey);
      if (customPath != null && customPath.isNotEmpty) {
        pathsToScan.add(customPath);
      }

      // 2. Obtener carpetas estándar (como fallback o adicionales)
      final docsDir = await getApplicationDocumentsDirectory();
      pathsToScan.add('${docsDir.path}/ZMusic');

      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          pathsToScan.add('${downloadsDir.path}/ZMusic');
        }
      } catch (_) {}

      print('DEBUG_SCAN: Escaneando rutas: $pathsToScan');

      for (var path in pathsToScan) {
        final dir = Directory(path);
        if (!await dir.exists()) {
          print('DEBUG_SCAN: Carpeta no existe: $path');
          continue;
        }

        // Usar list asíncrono para no bloquear el UI
        final Stream<FileSystemEntity> entityStream = dir.list(
          recursive: true,
          followLinks: false,
        );
        int processedCount = 0;

        await for (var entity in entityStream) {
          if (entity is File) {
            final ext = entity.path.toLowerCase();
            if (ext.endsWith('.mp3') ||
                ext.endsWith('.m4a') ||
                ext.endsWith('.flac') ||
                ext.endsWith('.wav')) {
              processedCount++;

              // Cada 20 archivos, un pequeño respiro para el UI
              if (processedCount % 20 == 0) {
                await Future.delayed(Duration.zero);
              }

              try {
                final file = entity;
                final stats = await file.stat();
                final fileName = file.path
                    .split(Platform.pathSeparator)
                    .last
                    .replaceAll(RegExp(r'\.[^.]+$'), '');

                // Intentar leer metadatos reales
                String title = fileName;
                String artist = 'Artista Desconocido';
                Duration duration = const Duration(minutes: 3);
                String? album;

                try {
                  // amr = audio_metadata_reader
                  final metadata = amr.readMetadata(file, getImage: false);
                  if (metadata.title != null && metadata.title!.isNotEmpty)
                    title = metadata.title!;
                  if (metadata.artist != null && metadata.artist!.isNotEmpty)
                    artist = metadata.artist!;
                  if (metadata.album != null && metadata.album!.isNotEmpty)
                    album = metadata.album!;
                  if (metadata.duration != null) duration = metadata.duration!;
                } catch (e) {
                  // Fallback silencioso si un archivo falla
                }

                results.add(
                  MusicTrack(
                    id: file.path,
                    songId: file.path.hashCode,
                    title: title,
                    artist: artist,
                    filePath: file.path,
                    duration: duration,
                    album: album,
                    size: stats.size,
                  ),
                );
              } catch (e) {
                print('Error crítico procesando ${entity.path}: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error en escaneo manual Windows: $e');
    }
    return results;
  }

  // Verificar si un archivo de audio es música real
  bool _isMusicFile(SongModel audioSong) {
    // 1. Verificar duración mínima (30 segundos = 30000 ms)
    // En Windows omitimos esta verificación por ahora o si es 0 (escaneo manual)
    if (!Platform.isWindows) {
      if (audioSong.duration == null || audioSong.duration! < 30000) {
        return false;
      }
    }

    // 2. Verificar que tenga una ruta válida
    if (audioSong.data.isEmpty) {
      return false;
    }

    // 3. Excluir rutas específicas (WhatsApp, Notifications, Ringtones, etc.)
    final path = audioSong.data.toLowerCase();
    final excludedPaths = [
      '/whatsapp/',
      '/notifications/',
      '/ringtones/',
      '/alarms/',
      '/recordings/',
      '/audiorecorder/',
      '/sounds/',
      '/telegram/',
      '/messenger/',
      '/android/media/com.whatsapp/',
      '/android/media/com.facebook.orca/',
      '/android/media/org.telegram.messenger/',
    ];

    for (var excludedPath in excludedPaths) {
      if (path.contains(excludedPath)) {
        return false;
      }
    }

    // 4. Verificar extensiones de archivo de música válidas
    final validExtensions = [
      '.mp3',
      '.m4a',
      '.flac',
      '.wav',
      '.aac',
      '.ogg',
      '.opus',
      '.wma',
    ];

    bool hasValidExtension = false;
    for (var ext in validExtensions) {
      if (path.endsWith(ext)) {
        hasValidExtension = true;
        break;
      }
    }

    if (!hasValidExtension) {
      return false;
    }

    return true;
  }

  // Cargar archivos de música manualmente (método alternativo)
  Future<String> loadMusicFromDevice() async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        return 'Permisos de almacenamiento denegados';
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newSongs = <MusicTrack>[];

        for (var file in result.files) {
          if (file.path != null) {
            final fileName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');

            final song = MusicTrack(
              id: DateTime.now().millisecondsSinceEpoch.toString() + file.name,
              songId: file.path.hashCode,
              title: fileName,
              artist: 'Artista Desconocido',
              filePath: file.path!,
              size: file.size,
            );

            newSongs.add(song);
          }
        }

        state = [...state, ...newSongs];

        return '${newSongs.length} canción(es) cargada(s) exitosamente';
      } else {
        return 'No se seleccionaron archivos';
      }
    } catch (e) {
      return 'Error al cargar música: $e';
    }
  }

  // Eliminar una canción de la biblioteca
  void removeSong(String songId) {
    state = state.where((song) => song.id != songId).toList();
  }

  // Limpiar toda la biblioteca
  void clearLibrary() {
    state = [];
  }

  // Actualizar información de una canción
  void updateSong(MusicTrack updatedSong) {
    state = [
      for (final song in state)
        if (song.id == updatedSong.id) updatedSong else song,
    ];
    _saveToCache(state);
  }

  // Alternar favorita
  Future<void> toggleFavorite(String songId) async {
    state = [
      for (final song in state)
        if (song.id == songId)
          song.copyWith(isFavorite: !song.isFavorite)
        else
          song,
    ];
    await _saveToCache(state);
  }

  // Refrescar la biblioteca (volver a escanear)
  Future<String> refreshLibrary() async {
    return await scanDeviceMusic();
  }

  // Windows: Seleccionar carpeta personalizada y escanear
  Future<String> pickFolderAndScan() async {
    if (!Platform.isWindows) return 'Solo disponible en Windows';

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecciona tu carpeta de música',
      );

      if (selectedDirectory != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_customFolderKey, selectedDirectory);
        return await scanDeviceMusic();
      }
      return 'No se seleccionó ninguna carpeta';
    } catch (e) {
      return 'Error al seleccionar carpeta: $e';
    }
  }

  // Obtener ruta de la carpeta personalizada actual
  Future<String?> getCustomFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customFolderKey);
  }
}
