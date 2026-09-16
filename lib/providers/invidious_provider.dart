import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:zmusic/services/invidious_service.dart';
import 'package:zmusic/providers/music_library_provider.dart';

// --- SEARCH PROVIDER ---

class InvidiousSearchNotifier extends Notifier<AsyncValue<List<InvidiousSong>>> {
  @override
  AsyncValue<List<InvidiousSong>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final results = await InvidiousService.search(query);
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final invidiousSearchProvider =
    NotifierProvider<InvidiousSearchNotifier, AsyncValue<List<InvidiousSong>>>(
  InvidiousSearchNotifier.new,
);

// --- DOWNLOAD PROVIDER ---

enum InvidiousDownloadStatus {
  idle,
  fetchingStream,
  downloading,
  processing,
  completed,
  error,
}

class InvidiousDownloadState {
  final String? activeSongId;
  final double progress;
  final InvidiousDownloadStatus status;
  final String message;
  final String speed;
  final Set<String> completedSongIds;

  const InvidiousDownloadState({
    this.activeSongId,
    this.progress = 0.0,
    this.status = InvidiousDownloadStatus.idle,
    this.message = '',
    this.speed = '',
    this.completedSongIds = const {},
  });

  InvidiousDownloadState copyWith({
    bool clearActiveSong = false,
    String? activeSongId,
    double? progress,
    InvidiousDownloadStatus? status,
    String? message,
    String? speed,
    Set<String>? completedSongIds,
  }) {
    return InvidiousDownloadState(
      activeSongId: clearActiveSong ? null : (activeSongId ?? this.activeSongId),
      progress: progress ?? this.progress,
      status: status ?? this.status,
      message: message ?? this.message,
      speed: speed ?? this.speed,
      completedSongIds: completedSongIds ?? this.completedSongIds,
    );
  }
}

class InvidiousDownloadNotifier extends Notifier<InvidiousDownloadState> {
  @override
  InvidiousDownloadState build() {
    return const InvidiousDownloadState();
  }

  Future<Uint8List?> _compressArtwork(Uint8List imageBytes) async {
    try {
      if (imageBytes.length < 500 * 1024) return imageBytes;
      final compressed = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      return Uint8List.fromList(compressed);
    } catch (_) {
      return imageBytes;
    }
  }

  Future<String?> downloadSong(InvidiousSong song) async {
    if (state.status == InvidiousDownloadStatus.downloading ||
        state.status == InvidiousDownloadStatus.fetchingStream ||
        state.status == InvidiousDownloadStatus.processing) {
      return null;
    }

    state = state.copyWith(
      activeSongId: song.id,
      progress: 0.0,
      status: InvidiousDownloadStatus.fetchingStream,
      message: 'Obteniendo enlace de audio de YouTube...',
    );

    try {
      // 1. Permisos de almacenamiento
      await ref.read(musicLibraryProvider.notifier).requestStoragePermission();

      // 2. Obtener enlace del stream
      final streamInfo = await InvidiousService.getAudioStream(song.id);
      if (streamInfo == null || streamInfo.url.isEmpty) {
        throw Exception('No se pudo obtener el stream de audio del video');
      }

      state = state.copyWith(
        status: InvidiousDownloadStatus.downloading,
        message: 'Iniciando descarga de audio (${streamInfo.container.toUpperCase()})...',
      );

      // 3. Directorio de guardado
      final String downloadPath;
      if (Platform.isAndroid) {
        downloadPath = '/storage/emulated/0/Download/ZMusic';
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        downloadPath = '${docsDir.path}/ZMusic';
      }

      final directory = Directory(downloadPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 4. Sanitizar nombre de archivo
      final cleanTitle =
          song.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final cleanArtist =
          song.author.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
      final fileName = '$cleanArtist - $cleanTitle';
      final ext = streamInfo.container;
      final targetFile = File('${directory.path}/$fileName.$ext');

      // 5. Descarga con Multi-Range en paralelo (acelerador de velocidad sin throttling)
      int totalBytes = streamInfo.totalBytes ?? 0;
      if (totalBytes <= 0) {
        try {
          final headRes = await http
              .head(Uri.parse(streamInfo.url))
              .timeout(const Duration(seconds: 4));
          totalBytes =
              int.tryParse(headRes.headers['content-length'] ?? '') ?? 0;
        } catch (_) {}
      }

      final speedWatch = Stopwatch()..start();
      int lastSpeedCheckTime = 0;
      int lastSpeedCheckBytes = 0;
      String currentSpeed = '';

      void updateSpeed(int currentDownloaded) {
        final now = speedWatch.elapsedMilliseconds;
        final timeDiff = now - lastSpeedCheckTime;
        if (timeDiff >= 350) {
          final bytesDiff = currentDownloaded - lastSpeedCheckBytes;
          final bytesPerSec = (bytesDiff / (timeDiff / 1000.0));
          if (bytesPerSec >= 1024 * 1024) {
            currentSpeed =
                '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
          } else {
            currentSpeed = '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
          }
          lastSpeedCheckTime = now;
          lastSpeedCheckBytes = currentDownloaded;
        }
      }

      bool downloadedWithMultiRange = false;

      // Si conocemos el tamaño (entre 1MB y 40MB), descargamos en 4 hilos paralelos
      if (totalBytes > 1024 * 1024 && totalBytes < 40 * 1024 * 1024) {
        try {
          const numWorkers = 4;
          final chunkSize = (totalBytes / numWorkers).ceil();
          final buffer = Uint8List(totalBytes);
          int totalDownloadedBytes = 0;
          int lastEmitted = 0;
          final emitThreshold =
              (totalBytes ~/ 40).clamp(64 * 1024, 256 * 1024);

          final workers = <Future<void>>[];

          for (int i = 0; i < numWorkers; i++) {
            final start = i * chunkSize;
            final end = (i == numWorkers - 1)
                ? totalBytes - 1
                : ((i + 1) * chunkSize) - 1;
            if (start >= totalBytes) break;

            workers.add(() async {
              final client = http.Client();
              try {
                final req = http.Request('GET', Uri.parse(streamInfo.url));
                req.headers['User-Agent'] =
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
                req.headers['Range'] = 'bytes=$start-$end';

                final res = await client.send(req);
                if (res.statusCode != 200 && res.statusCode != 206) {
                  throw Exception('HTTP ${res.statusCode}');
                }

                int writeOffset = start;
                await for (final chunk in res.stream) {
                  buffer.setRange(
                    writeOffset,
                    writeOffset + chunk.length,
                    chunk,
                  );
                  writeOffset += chunk.length;
                  totalDownloadedBytes += chunk.length;

                  updateSpeed(totalDownloadedBytes);

                  if (totalDownloadedBytes - lastEmitted >= emitThreshold ||
                      totalDownloadedBytes >= totalBytes) {
                    lastEmitted = totalDownloadedBytes;
                    final progress =
                        (totalDownloadedBytes / totalBytes).clamp(0.0, 1.0);
                    state = state.copyWith(
                      progress: progress,
                      speed: currentSpeed,
                      message:
                          'Descargando: ${(totalDownloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    );
                  }
                }
              } finally {
                client.close();
              }
            }());
          }

          await Future.wait(workers);
          await targetFile.writeAsBytes(buffer);
          downloadedWithMultiRange = true;
        } catch (e) {
          debugPrint(
            'DEBUG_INVIDIOUS: Multi-range falló ($e), usando stream secuencial...',
          );
        }
      }

      // Fallback a stream secuencial si falló el modo multi-range
      if (!downloadedWithMultiRange) {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(streamInfo.url));
        request.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

        final response = await client.send(request);

        if (response.statusCode != 200 && response.statusCode != 206) {
          throw Exception('YouTube denegó acceso a este video (HTTP ${response.statusCode})');
        }

        final fileTotal = response.contentLength ?? totalBytes;
        int downloadedBytes = 0;
        final fileStream = targetFile.openWrite();
        int lastEmittedBytes = 0;
        final emitThreshold = fileTotal > 0
            ? (fileTotal ~/ 50).clamp(64 * 1024, 256 * 1024)
            : 64 * 1024;

        await for (final chunk in response.stream) {
          fileStream.add(chunk);
          downloadedBytes += chunk.length;

          updateSpeed(downloadedBytes);

          if (downloadedBytes - lastEmittedBytes >= emitThreshold ||
              downloadedBytes == fileTotal) {
            lastEmittedBytes = downloadedBytes;
            if (fileTotal > 0) {
              final progress = (downloadedBytes / fileTotal).clamp(0.0, 1.0);
              state = state.copyWith(
                progress: progress,
                speed: currentSpeed,
                message:
                    'Descargando: ${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(fileTotal / (1024 * 1024)).toStringAsFixed(1)} MB',
              );
            }
          }
        }

        await fileStream.flush();
        await fileStream.close();
        client.close();
      }

      speedWatch.stop();

      // Validar que el archivo no esté vacío
      if (!await targetFile.exists() || await targetFile.length() < 1000) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        throw Exception('El archivo descargado está vacío (Google Video bloqueó la IP de este enlace)');
      }

      // 6. Descargar carátula e incrustar metadatos
      state = state.copyWith(
        status: InvidiousDownloadStatus.processing,
        progress: 0.95,
        speed: '',
        message: 'Aplicando metadatos y carátula...',
      );

      Uint8List? artworkBytes;
      if (song.thumbnailUrl.isNotEmpty) {
        try {
          final imgRes = await http
              .get(Uri.parse(song.thumbnailUrl))
              .timeout(const Duration(seconds: 6));
          if (imgRes.statusCode == 200 && imgRes.bodyBytes.length > 2000) {
            artworkBytes = await _compressArtwork(imgRes.bodyBytes);
          }
        } catch (_) {}
      }

      try {
        amr.updateMetadata(targetFile, (metadata) {
          metadata.setTitle(song.title);
          metadata.setArtist(song.author);
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
      } catch (e) {
        debugPrint('DEBUG_INVIDIOUS: No se pudieron incrustar metadatos: $e');
      }

      // 7. Notificar inmediatamente que se completó
      final newCompleted = Set<String>.from(state.completedSongIds)
        ..add(song.id);
      state = state.copyWith(
        clearActiveSong: true,
        progress: 1.0,
        status: InvidiousDownloadStatus.completed,
        message: '¡Descarga completada con éxito!',
        completedSongIds: newCompleted,
      );

      // 8. Escaneo Android y refresco de biblioteca en segundo plano
      if (Platform.isAndroid) {
        try {
          final audioQuery = OnAudioQuery();
          await audioQuery.scanMedia(targetFile.path);
        } catch (_) {}
      }
      ref.read(musicLibraryProvider.notifier).scanDeviceMusic();

      return targetFile.path;
    } catch (e) {
      debugPrint('DEBUG_INVIDIOUS: Error en descarga: $e');
      state = state.copyWith(
        clearActiveSong: true,
        status: InvidiousDownloadStatus.error,
        message: 'Error al descargar: $e',
      );
      return null;
    }
  }
}

final invidiousDownloadProvider =
    NotifierProvider<InvidiousDownloadNotifier, InvidiousDownloadState>(
  InvidiousDownloadNotifier.new,
);
