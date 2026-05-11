import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:zmusic/providers/music_library_provider.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

class YouTubeSearchResult {
  final List<YouTubeVideoResult> videos;
  final bool isPlaylist;

  YouTubeSearchResult({required this.videos, required this.isPlaylist});
}

enum DownloadStatus {
  analyzing, // Analizando enlace
  fetchingManifest, // Obteniendo información
  selectingQuality, // Seleccionando calidad
  downloadingThumbnail, // Descargando portada
  downloading, // Descargando audio
  writingMetadata, // Guardando información
  finalizing, // Finalizando
}

class DownloadState {
  final double progress;
  final YouTubeVideoResult video;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;

  DownloadState({
    required this.progress,
    required this.video,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
  });
}

@riverpod
class YouTubeSearch extends _$YouTubeSearch {
  final _yt = YoutubeExplode();

  @override
  FutureOr<YouTubeSearchResult> build() =>
      YouTubeSearchResult(videos: [], isPlaylist: false);

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = AsyncValue.data(
        YouTubeSearchResult(videos: [], isPlaylist: false),
      );
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      PlaylistId? playlistId;
      final trimmedQuery = query.trim();

      bool looksLikePlaylist =
          trimmedQuery.contains('youtube.com') ||
          trimmedQuery.contains('youtu.be') ||
          trimmedQuery.startsWith('PL') ||
          trimmedQuery.startsWith('RD');

      if (looksLikePlaylist) {
        try {
          playlistId = PlaylistId(trimmedQuery);
        } catch (_) {}
      }

      if (playlistId != null) {
        final playlistVideos = await _yt.playlists
            .getVideos(playlistId)
            .toList();
        return YouTubeSearchResult(
          videos: playlistVideos
              .map(
                (video) => YouTubeVideoResult(
                  id: video.id.value,
                  title: video.title,
                  author: video.author,
                  duration: video.duration,
                  thumbnailUrl: video.thumbnails.mediumResUrl,
                ),
              )
              .toList(),
          isPlaylist: true,
        );
      }

      final results = await _yt.search.search(query);
      return YouTubeSearchResult(
        videos: results
            .map(
              (video) => YouTubeVideoResult(
                id: video.id.value,
                title: video.title,
                author: video.author,
                duration: video.duration,
                thumbnailUrl: video.thumbnails.mediumResUrl,
              ),
            )
            .toList(),
        isPlaylist: false,
      );
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

  Map<String, String> _parseVideoTitle(
    String videoTitle,
    String channelAuthor,
  ) {
    // Limpiar texto común de YouTube
    String cleanTitle = videoTitle
        .replaceAll(
          RegExp(
            r'\((Official|Audio|Video|Lyric|MV).*?\)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\[(Official|Audio|Video|Lyric|MV).*?\]',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

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
      '-',
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

    return {
      'artist': channelAuthor.replaceAll(' - Topic', '').trim(),
      'title': cleanTitle,
    };
  }

  // Función auxiliar para comprimir imágenes de portada
  Future<Uint8List?> _compressArtwork(Uint8List imageBytes) async {
    try {
      final originalSize = imageBytes.length;

      // Si la imagen es menor a 500KB, no comprimir
      if (originalSize < 500 * 1024) {
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

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      return imageBytes; // Retornar original si falla la compresión
    }
  }

  // Función auxiliar para validar si es seguro modificar metadatos
  bool _isSafeToModifyMetadata(File file) {
    try {
      final fileSize = file.lengthSync();
      final fileSizeMB = fileSize / (1024 * 1024);

      // Límite de 200MB para modificar metadatos de forma segura
      if (fileSizeMB > 200) {
        // Archivo muy grande
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> downloadAudio(YouTubeVideoResult video) async {
    try {
      state = DownloadState(
        progress: 0.0,
        video: video,
        totalBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.analyzing,
      );

      // 1. Solicitar permisos
      await ref.read(musicLibraryProvider.notifier).requestStoragePermission();

      // 2. Verificar si podemos leer detalles del video primero
      Video? fullVideo;
      try {
        print('DEBUG_YT: Solicitando información del video a YouTube...');
        fullVideo = await _yt.videos
            .get(video.id)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Se agotó el tiempo esperando la info del video',
                );
              },
            );
        print('DEBUG_YT: Información obtenida correctamente.');
      } catch (e) {
        print('DEBUG_YT: Error obteniendo info del video: $e');
        print(
          'DEBUG_YT: Usando la información básica del video como respaldo.',
        );
        fullVideo = null; // Fallback to video.thumbnailUrl later
      }

      print('DEBUG_YT: Solicitando el manifiesto de streams...');
      // 3. Obtener el manifiesto
      state = DownloadState(
        progress: 0.0,
        video: video,
        totalBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.fetchingManifest,
      );

      StreamManifest? manifest;
      try {
        manifest = await _yt.videos.streams
            .getManifest(video.id, ytClients: [YoutubeApiClient.androidVr])
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw 'TIMEOUT_MANIFEST';
              },
            );
      } catch (e) {
        print('DEBUG_YT: Error obteniendo el manifiesto: $e');
        if (e == 'TIMEOUT_MANIFEST') {
          throw Exception(
            'Tiempo de espera agotado (30s). YouTube está bloqueando la conexión.',
          );
        }
        rethrow;
      }

      // 4. Seleccionar el mejor stream de audio (priorizando MP4/M4A)
      state = DownloadState(
        progress: 0.0,
        video: video,
        totalBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.selectingQuality,
      );

      final audioStreams = manifest.audioOnly.where(
        (s) => s.container.name == 'mp4',
      );
      final audioStream = audioStreams.isNotEmpty
          ? audioStreams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      final extension = audioStream.container.name == 'mp4'
          ? 'm4a'
          : audioStream.container.name;
      final String downloadPath;
      if (Platform.isAndroid) {
        downloadPath = '/storage/emulated/0/Download/ZMusic';
      } else {
        // Para Windows/otros, usar la carpeta de Documentos
        final docsDir = await getApplicationDocumentsDirectory();
        downloadPath = '${docsDir.path}/ZMusic';
      }

      final directory = Directory(downloadPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final parsed = _parseVideoTitle(video.title, video.author);
      final artist = parsed['artist']!;
      final title = parsed['title']!;
      final fileName = '$artist - $title'
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final file = File('${directory.path}/$fileName.$extension');

      // 5. Descargar miniatura (Mejor resolución real posible)
      print('DEBUG_YT: Iniciando descarga de miniatura');
      state = DownloadState(
        progress: 0.0,
        video: video,
        totalBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.downloadingThumbnail,
      );

      try {
        final thumbCandidates = [
          if (fullVideo?.thumbnails.maxResUrl.isNotEmpty == true)
            fullVideo!.thumbnails.maxResUrl,
          if (fullVideo?.thumbnails.highResUrl.isNotEmpty == true)
            fullVideo!.thumbnails.highResUrl,
          if (fullVideo?.thumbnails.standardResUrl.isNotEmpty == true)
            fullVideo!.thumbnails.standardResUrl,
          video.thumbnailUrl,
        ];

        Uint8List? bestImageBytes;
        for (String url in thumbCandidates) {
          print('DEBUG_YT: Probando URL de miniatura: $url');
          try {
            final response = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              if (response.bodyBytes.length > 5000) {
                bestImageBytes = response.bodyBytes;
                print('DEBUG_YT: Miniatura obtenida correctamente');
                break;
              } else {
                print('DEBUG_YT: Miniatura demasiado pequeña');
              }
            } else {
              print(
                'DEBUG_YT: Error HTTP en miniatura: ${response.statusCode}',
              );
            }
          } catch (e) {
            print('DEBUG_YT: Error obteniendo miniatura: $e');
          }
        }

        if (bestImageBytes != null) {
          final thumbnailFile = File('${directory.path}/$fileName.jpg');
          await thumbnailFile.writeAsBytes(bestImageBytes);
        }
      } catch (e) {
        print('DEBUG_YT: Error global en descarga de miniatura: $e');
      }

      print('DEBUG_YT: Iniciando descarga de stream de audio');
      // 5. Descargar
      state = DownloadState(
        progress: 0.0,
        video: video,
        totalBytes: audioStream.size.totalBytes,
        downloadedBytes: 0,
        status: DownloadStatus.downloading,
      );

      print('DEBUG_YT: Obteniendo stream de YoutubeExplode');
      // Usar el propio cliente de YoutubeExplode en lugar de HTTP directo
      // para asegurar que las cabeceras/firmas coincidan.
      final stream = _yt.videos.streams.get(audioStream);

      print('DEBUG_YT: Abriendo archivo para escritura');
      final fileStream = file.openWrite();
      int downloadedBytes = 0;

      try {
        print('DEBUG_YT: Escuchando chunks del stream');
        await for (final chunk in stream.timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            print('DEBUG_YT: Timeout del stream detectado durante la descarga');
            sink.addError(
              Exception(
                'El servidor de YouTube limitó la velocidad a cero (Timeout).',
              ),
            );
          },
        )) {
          fileStream.add(chunk);
          downloadedBytes += chunk.length;
          final currentProgress =
              (downloadedBytes / audioStream.size.totalBytes).clamp(0.0, 1.0);

          if (downloadedBytes == chunk.length) {
            print('DEBUG_YT: Primer chunk recibido, descargando...');
          }

          state = DownloadState(
            progress: currentProgress,
            video: video,
            totalBytes: audioStream.size.totalBytes,
            downloadedBytes: downloadedBytes,
            status: currentProgress < 0.95
                ? DownloadStatus.downloading
                : DownloadStatus.finalizing,
          );
        }
        print('DEBUG_YT: Descarga de chunks terminada');
      } catch (e) {
        print('DEBUG_YT: Excepción durante la descarga del stream: $e');
        await fileStream.close();
        if (await file.exists()) {
          await file.delete();
        }
        throw Exception('Error al descargar el audio: $e');
      }

      print('DEBUG_YT: Haciendo flush y close del fileStream');
      await fileStream.flush();
      await fileStream.close();

      // Metadatos usando audio_metadata_reader (AMR)
      try {
        if (_isSafeToModifyMetadata(file)) {
          state = DownloadState(
            progress: 0.98,
            video: video,
            totalBytes: audioStream.size.totalBytes,
            downloadedBytes: audioStream.size.totalBytes,
            status: DownloadStatus.writingMetadata,
          );

          final thumbnailFile = File('${directory.path}/$fileName.jpg');
          Uint8List? artworkBytes;

          if (await thumbnailFile.exists()) {
            final originalBytes = await thumbnailFile.readAsBytes();
            artworkBytes = await _compressArtwork(originalBytes);
          }

          // Aplicar metadatos usando AMR
          try {
            amr.updateMetadata(file, (metadata) {
              metadata.setTitle(title);
              metadata.setArtist(artist);
              if (artworkBytes != null) {
                metadata.setPictures([
                  amr.Picture(
                    artworkBytes,
                    'image/jpeg',
                    amr.PictureType.coverFront,
                  ),
                ]);
              }
            });
          } catch (_) {}

          // Limpiar miniatura temporal
          if (await thumbnailFile.exists()) {
            await thumbnailFile.delete();
          }
        } else {}
      } catch (_) {}

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
      } catch (_) {}
    }
  }

  void dispose() {
    _yt.close();
  }
}
