import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:flutter_audio_tagger/flutter_audio_tagger.dart';
import 'package:flutter_audio_tagger/tag.dart' as fat;
import 'package:zmusic/providers/music_library_provider.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
//import 'package:metadata_god/metadata_god.dart' as mg;

part 'youtube_provider.g.dart';

class YouTubeVideoResult {
  final String id;
  final String title;
  final String author;
  final Duration? duration;
  final String thumbnailUrl;

  YouTubeVideoResult({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    required this.thumbnailUrl,
  });
}

class DownloadState {
  final double progress;
  final YouTubeVideoResult video;

  DownloadState({required this.progress, required this.video});
}

@riverpod
class YouTubeSearch extends _$YouTubeSearch {
  final _yt = YoutubeExplode();

  @override
  FutureOr<List<YouTubeVideoResult>> build() => [];

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Intentar detectar si es una Playlist ID o URL
      PlaylistId? playlistId;
      try {
        playlistId = PlaylistId(query);
      } catch (_) {
        // No es un ID de playlist válido
      }

      if (playlistId != null) {
        // Si es una playlist, obtener todos sus videos
        final playlistVideos = await _yt.playlists
            .getVideos(playlistId)
            .toList();
        return playlistVideos
            .map(
              (video) => YouTubeVideoResult(
                id: video.id.value,
                title: video.title,
                author: video.author,
                duration: video.duration,
                thumbnailUrl: video.thumbnails.mediumResUrl,
              ),
            )
            .toList();
      }

      // Si no es playlist, realizar búsqueda normal
      final results = await _yt.search.search(query);
      return results
          .map(
            (video) => YouTubeVideoResult(
              id: video.id.value,
              title: video.title,
              author: video.author,
              duration: video.duration,
              thumbnailUrl: video.thumbnails.mediumResUrl,
            ),
          )
          .toList();
    });
  }

  void dispose() {
    _yt.close();
  }
}

@riverpod
class YouTubeDownload extends _$YouTubeDownload {
  final _yt = YoutubeExplode();

  @override
  DownloadState? build() => null; // null if not downloading

  // Helper para extraer artista y título del nombre del video
  Map<String, String> _parseVideoTitle(
    String videoTitle,
    String channelAuthor,
  ) {
    // Limpiar texto común de YouTube
    String cleanTitle = videoTitle
        .replaceAll(RegExp(r'\(Official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Audio.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Audio.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Video.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Lyric.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Lyric.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(MV.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[MV.*?\]', caseSensitive: false), '')
        .trim();

    // Separadores comunes con y sin espacios
    final separators = [
      ' - ',
      ' – ',
      ' — ',
      ' vs. ',
      ' vs ',
      ': ',
      ' | ',
      ' ft. ',
      ' feat. ',
      ' FT ',
      ' FEAT ',
      '-', // Último recurso: guion solo si no hay espacios
    ];

    for (var separator in separators) {
      if (cleanTitle.contains(separator)) {
        final parts = cleanTitle.split(separator);
        if (parts.length >= 2) {
          final artist = parts[0].trim();
          final title = parts.sublist(1).join(separator).trim();
          if (artist.isNotEmpty && title.isNotEmpty) {
            return {'artist': artist, 'title': title};
          }
        }
      }
    }

    // Fallback: Si no hay separador, usar el autor del canal como artista
    return {
      'artist': channelAuthor.replaceAll(' - Topic', '').trim(),
      'title': cleanTitle,
    };
  }

  // Función auxiliar para comprimir imágenes de portada
  Future<Uint8List?> _compressArtwork(Uint8List imageBytes) async {
    try {
      final originalSize = imageBytes.length;
      print(
        'YT_DEBUG: Tamaño original de imagen: ${(originalSize / 1024).toStringAsFixed(2)} KB',
      );

      // Si la imagen es menor a 500KB, no comprimir
      if (originalSize < 500 * 1024) {
        print('YT_DEBUG: Imagen ya es pequeña, no se comprime');
        return imageBytes;
      }

      // Comprimir la imagen a máximo 800x800 con calidad 85
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      final compressedSize = compressedBytes.length;
      final reduction = ((1 - compressedSize / originalSize) * 100)
          .toStringAsFixed(1);
      print(
        'YT_DEBUG: Imagen comprimida: ${(compressedSize / 1024).toStringAsFixed(2)} KB (reducción: $reduction%)',
      );

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('YT_DEBUG: Error al comprimir imagen: $e');
      return imageBytes; // Retornar original si falla la compresión
    }
  }

  // Función auxiliar para validar si es seguro modificar metadatos
  bool _isSafeToModifyMetadata(File file) {
    try {
      final fileSize = file.lengthSync();
      final fileSizeMB = fileSize / (1024 * 1024);
      print(
        'YT_DEBUG: Tamaño del archivo de audio: ${fileSizeMB.toStringAsFixed(2)} MB',
      );

      // Límite de 200MB para modificar metadatos de forma segura
      if (fileSizeMB > 200) {
        print(
          'YT_DEBUG: ⚠️ Archivo muy grande (>${fileSizeMB.toStringAsFixed(0)}MB), saltando metadatos',
        );
        return false;
      }

      return true;
    } catch (e) {
      print('YT_DEBUG: Error al verificar tamaño de archivo: $e');
      return false;
    }
  }

  Future<String?> downloadAudio(YouTubeVideoResult video) async {
    try {
      print('YT_DEBUG: Iniciando descarga para ID: ${video.id}');
      state = DownloadState(progress: 0.0, video: video);

      // 1. Solicitar permisos
      await ref.read(musicLibraryProvider.notifier).requestStoragePermission();
      print('YT_DEBUG: Permisos verificados');

      // 2. Verificar si podemos leer detalles del video primero
      Video? fullVideo;
      try {
        print('YT_DEBUG: Verificando detalles del video...');
        fullVideo = await _yt.videos.get(video.id);
        print('YT_DEBUG: Video verificado: "${fullVideo.title}"');
      } catch (e) {
        print('YT_DEBUG: Error al obtener detalles básicos: $e');
        throw Exception('YouTube no permite leer este video: $e');
      }

      // 3. Obtener el manifiesto
      print(
        'YT_DEBUG: Intentando obtener manifiesto con clientes ios/androidVr...',
      );
      StreamManifest? manifest;
      try {
        manifest = await _yt.videos.streams
            .getManifest(
              video.id,
              ytClients: [YoutubeApiClient.android, YoutubeApiClient.ios],
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                print('YT_DEBUG: TIMEOUT (30s) al obtener manifiesto');
                throw 'TIMEOUT_MANIFEST';
              },
            );
        print('YT_DEBUG: Manifiesto obtenido con éxito');
      } catch (e) {
        print('YT_DEBUG: ERROR crítico al obtener manifiesto: $e');
        if (e == 'TIMEOUT_MANIFEST') {
          throw Exception(
            'Tiempo de espera agotado (30s). YouTube está bloqueando la conexión.',
          );
        }
        rethrow;
      }

      // 4. Seleccionar el mejor stream de audio (priorizando MP4/M4A)
      final audioStreams = manifest.audioOnly.where(
        (s) => s.container.name == 'mp4',
      );
      final audioStream = audioStreams.isNotEmpty
          ? audioStreams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      print(
        'YT_DEBUG: Stream seleccionado: ${audioStream.container.name} (${audioStream.bitrate})',
      );

      final extension = audioStream.container.name == 'mp4'
          ? 'm4a'
          : audioStream.container.name;
      final directory = Directory('/storage/emulated/0/Download/ZMusic');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        print('YT_DEBUG: Directorio creado: ${directory.path}');
      }

      final parsed = _parseVideoTitle(video.title, video.author);
      final artist = parsed['artist']!;
      final title = parsed['title']!;
      print('YT_DEBUG: Parsed Title: "$title", Artist: "$artist"');
      final fileName = '$artist - $title'
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final file = File('${directory.path}/$fileName.$extension');
      print('YT_DEBUG: Archivo destino: ${file.path}');

      // Descargar miniatura (Mejor resolución posible)
      try {
        print('YT_DEBUG: Descargando miniatura de alta resolución...');
        // Priorizar: maxResUrl -> highResUrl -> standardResUrl -> thumbnailUrl
        String thumbUrl = video.thumbnailUrl;
        if (fullVideo.thumbnails.maxResUrl.isNotEmpty) {
          thumbUrl = fullVideo.thumbnails.maxResUrl;
        } else if (fullVideo.thumbnails.highResUrl.isNotEmpty) {
          thumbUrl = fullVideo.thumbnails.highResUrl;
        } else if (fullVideo.thumbnails.standardResUrl.isNotEmpty) {
          thumbUrl = fullVideo.thumbnails.standardResUrl;
        }

        print('YT_DEBUG: Usando URL de miniatura: $thumbUrl');
        final response = await http.get(Uri.parse(thumbUrl));
        if (response.statusCode == 200) {
          final thumbnailFile = File('${directory.path}/$fileName.jpg');
          await thumbnailFile.writeAsBytes(response.bodyBytes);
          print(
            'YT_DEBUG: Miniatura (${response.bodyBytes.length} bytes) guardada temporalmente',
          );
        }
      } catch (e) {
        print('YT_DEBUG: Error al descargar miniatura: $e');
      }

      // 5. Descargar
      print('YT_DEBUG: Iniciando stream de descarga...');
      final stream = _yt.videos.streams.get(audioStream);
      final fileStream = file.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in stream) {
        fileStream.add(chunk);
        downloadedBytes += chunk.length;
        state = DownloadState(
          progress: (downloadedBytes / audioStream.size.totalBytes).clamp(
            0.0,
            1.0,
          ),
          video: video,
        );
      }

      await fileStream.flush();
      await fileStream.close();
      print('YT_DEBUG: Descarga de archivo completada');

      // Metadatos automáticos usando audio_metadata_reader
      try {
        // Validar si es seguro modificar metadatos basado en el tamaño del archivo
        if (!_isSafeToModifyMetadata(file)) {
          print(
            'YT_DEBUG: ⚠️ Archivo demasiado grande, omitiendo modificación de metadatos',
          );
          print(
            'YT_DEBUG: El archivo se descargó correctamente pero sin metadatos incrustados',
          );
        } else {
          print('YT_DEBUG: Iniciando incrustación de metadatos...');
          print('YT_DEBUG: Archivo: ${file.path}');
          print('YT_DEBUG: Título a escribir: "$title"');
          print('YT_DEBUG: Artista a escribir: "$artist"');

          final thumbnailFile = File('${directory.path}/$fileName.jpg');
          Uint8List? artworkBytes;

          if (await thumbnailFile.exists()) {
            final originalBytes = await thumbnailFile.readAsBytes();
            print(
              'YT_DEBUG: Imagen de portada descargada (${(originalBytes.length / 1024).toStringAsFixed(2)} KB)',
            );

            // Comprimir la imagen antes de incrustarla
            artworkBytes = await _compressArtwork(originalBytes);

            if (artworkBytes != null) {
              print('YT_DEBUG: ✅ Imagen lista para incrustar');
            }
          } else {
            print('YT_DEBUG: ⚠️ No se encontró archivo de miniatura');
          }

          // Usar flutter_audio_tagger para incrustar metadatos y portada
          bool metadataSuccess = false;
          try {
            print(
              'YT_DEBUG: Iniciando incrustación de metadatos con flutter_audio_tagger...',
            );
            final tagger = FlutterAudioTagger();

            final tagToSet = fat.Tag(
              title: title,
              artist: artist,
              artwork: artworkBytes,
            );

            try {
              print('YT_DEBUG: Intento 1: editTagsAndArtwork (con portada)...');
              final result = await tagger.editTagsAndArtwork(
                tagToSet,
                file.path,
              );
              await file.writeAsBytes(result.musicData);
              print('YT_DEBUG: ✅ Metadatos y portada incrustados con éxito');
              metadataSuccess = true;
            } catch (e) {
              print(
                'YT_DEBUG: ⚠️ Falló con portada. Intento 2: solo texto (editTags)...',
              );
              try {
                final textResult = await tagger.editTags(tagToSet, file.path);
                await file.writeAsBytes(textResult.musicData);
                print(
                  'YT_DEBUG: ✅ Al menos el Título y Artista fueron incrustados',
                );
                metadataSuccess = true;
              } catch (e2) {
                print(
                  'YT_DEBUG: ⚠️ Falló también solo texto. Intento 3: Fallback a AMR...',
                );
                try {
                  amr.updateMetadata(file, (m) {
                    m.setTitle(title);
                    m.setArtist(artist);
                    if (artworkBytes != null) {
                      m.setPictures([
                        amr.Picture(
                          artworkBytes,
                          'image/jpeg',
                          amr.PictureType.coverFront,
                        ),
                      ]);
                    }
                  });
                  await Future.delayed(const Duration(milliseconds: 500));
                  print(
                    'YT_DEBUG: ✅ Guardado usando fallback de audio_metadata_reader',
                  );
                  metadataSuccess = true;
                } catch (e3) {
                  print(
                    'YT_DEBUG: ❌ Todos los métodos de guardado fallaron para este archivo.',
                  );
                }
              }
            }
          } catch (e, _) {
            print('YT_DEBUG: ❌ Error crítico en motor de etiquetas: $e');
            metadataSuccess = false;
          }

          if (!metadataSuccess) {
            print(
              'YT_DEBUG: ❌ No se pudieron escribir metadatos con ninguna biblioteca',
            );
            print(
              'YT_DEBUG: El archivo de audio se descargó correctamente pero sin metadatos',
            );
          }
        }

        // Limpiar archivo temporal de miniatura
        final thumbnailFile = File('${directory.path}/$fileName.jpg');
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
          print('YT_DEBUG: Archivo temporal de imagen eliminado');
        }
      } catch (e, stackTrace) {
        print('YT_DEBUG: ❌ ERROR METADATOS: $e');
        print('YT_DEBUG: StackTrace: $stackTrace');
        print(
          'YT_DEBUG: El archivo de audio se descargó correctamente, pero falló la incrustación de metadatos',
        );
      }

      // Notificar MediaStore
      try {
        final audioQuery = OnAudioQuery();
        await audioQuery.scanMedia(file.path);
      } catch (_) {}

      state = null;
      await Future.delayed(const Duration(seconds: 1));
      await ref.read(musicLibraryProvider.notifier).scanDeviceMusic();

      return file.path;
    } catch (e) {
      state = null;
      rethrow;
    }
  }

  Future<void> downloadMultiple(List<YouTubeVideoResult> videos) async {
    for (var video in videos) {
      try {
        await downloadAudio(video);
      } catch (e) {
        print('YT_DEBUG: Error al descargar item de lista: $e');
      }
    }
  }

  void dispose() {
    _yt.close();
  }
}
