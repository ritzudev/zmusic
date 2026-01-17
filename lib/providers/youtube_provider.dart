import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:zmusic/providers/music_library_provider.dart';

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
  Map<String, String> _parseVideoTitle(String videoTitle) {
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
        .trim();

    final separators = [' - ', ' – ', ' — ', ': ', ' | ', ' ft. ', ' feat. '];

    for (var separator in separators) {
      if (cleanTitle.contains(separator)) {
        final parts = cleanTitle.split(separator);
        if (parts.length >= 2) {
          return {
            'artist': parts[0].trim(),
            'title': parts.sublist(1).join(separator).trim(),
          };
        }
      }
    }

    return {'artist': 'Artista Desconocido', 'title': cleanTitle};
  }

  Future<String?> downloadAudio(YouTubeVideoResult video) async {
    try {
      state = DownloadState(progress: 0.0, video: video);

      // 1. Solicitar permisos
      await ref.read(musicLibraryProvider.notifier).requestStoragePermission();

      // 2. Obtener el manifiesto
      final manifest = await _yt.videos.streams
          .getManifest(
            video.id,
            ytClients: [YoutubeApiClient.ios, YoutubeApiClient.androidVr],
          )
          .timeout(const Duration(seconds: 15));

      // 3. Seleccionar el mejor stream de audio (priorizando MP4/M4A)
      final audioStreams = manifest.audioOnly.where(
        (s) => s.container.name == 'mp4',
      );
      final audioStream = audioStreams.isNotEmpty
          ? audioStreams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      if (audioStream == null)
        throw Exception('No se encontró un stream de audio');

      final extension = audioStream.container.name == 'mp4'
          ? 'm4a'
          : audioStream.container.name;
      final directory = Directory('/storage/emulated/0/Download/ZMusic');
      if (!await directory.exists()) await directory.create(recursive: true);

      final parsed = _parseVideoTitle(video.title);
      final artist = parsed['artist']!;
      final title = parsed['title']!;
      final fileName = '$artist - $title'
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();
      final file = File('${directory.path}/$fileName.$extension');

      // Descargar miniatura
      try {
        final response = await http.get(Uri.parse(video.thumbnailUrl));
        if (response.statusCode == 200) {
          final thumbnailFile = File('${directory.path}/$fileName.jpg');
          await thumbnailFile.writeAsBytes(response.bodyBytes);
        }
      } catch (_) {}

      // 5. Descargar
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

      // Metadatos deshabilitados temporalmente para pruebas
      /*
      try {
        final thumbFile = File('${directory.path}/$fileName.jpg');
        // ... (lógica de metadatos)
      } catch (e) {
        print('YT_DEBUG: Error al incrustar metadatos: $e');
      }
      */

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
