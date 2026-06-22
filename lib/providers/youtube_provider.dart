import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/providers/settings_provider.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
part 'youtube_provider.g.dart';

String? _globalGuestCookies;

Future<String?> _fetchGuestCookies() async {
  try {
    print('DEBUG_YT: [COOKIES] Intentando obtener cookies de invitado de YouTube automáticamente...');
    final client = http.Client();
    final response = await client.get(
      Uri.parse('https://www.youtube.com'),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9,es-ES;q=0.8,es;q=0.7',
      },
    ).timeout(const Duration(seconds: 10));
    
    final rawCookies = response.headers['set-cookie'];
    client.close();

    if (rawCookies != null && rawCookies.isNotEmpty) {
      final cookieMap = <String, String>{};
      List<String> cookiesList;
      try {
        cookiesList = rawCookies.split(RegExp(r',(?=[^;]+?=)'));
      } catch (_) {
        cookiesList = [rawCookies];
      }

      for (var cookie in cookiesList) {
        final cookiePart = cookie.split(';')[0].trim();
        final eqIdx = cookiePart.indexOf('=');
        if (eqIdx != -1) {
          final key = cookiePart.substring(0, eqIdx).trim();
          final val = cookiePart.substring(eqIdx + 1).trim();
          if (key.isNotEmpty) {
            cookieMap[key] = val;
          }
        }
      }
      
      if (cookieMap.isNotEmpty) {
        final cookieString = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
        print('DEBUG_YT: [COOKIES] Cookies de invitado obtenidas con éxito: $cookieString');
        return cookieString;
      }
    }
    print('DEBUG_YT: [COOKIES] No se encontraron cabeceras set-cookie.');
  } catch (e) {
    print('DEBUG_YT: [COOKIES] Error obteniendo cookies de invitado: $e');
  }
  print('DEBUG_YT: [COOKIES] Usando cookies de respaldo (fallback).');
  return r'VISITOR_INFO1_LIVE=8_AxKfLl4sI; VISITOR_PRIVACY_METADATA=CgJQRRIEGgAgXQ%3D%3D; __Secure-BUCKET=CMQC; HSID=AqzN3hPrq_zlVfdIP; SSID=A693IzYP3AB_PmJEo; APISID=nhCwyV1BJY3jVWfa/AKMtt_q9Sff0FLppV; SAPISID=lXgNWXgpNBdXevjs/A-r3RGKf1oa3bBg1g; __Secure-1PAPISID=lXgNWXgpNBdXevjs/A-r3RGKf1oa3bBg1g; __Secure-3PAPISID=lXgNWXgpNBdXevjs/A-r3RGKf1oa3bBg1g; _gcl_au=1.1.649619280.1779583533; _ga=GA1.1.1767845344.1779583533; _ga_VCGEPY40VB=GS2.1.s1779583533$o1$g1$t1779583568$j25$l0$h0; PREF=f6=40000000&tz=America.Lima&f5=20000&f7=150&repeat=NONE&autoplay=true; LOGIN_INFO=AFmmF2swRQIhAMamKrjFjya7Es-vOkq1j72SrtJs0ol1lD5TcMwjYa2uAiAPttAeK26z45j010g3hQeUiBmyx0JX4wBMXTLdQINmfA:QUQ3MjNmeUF5ay01bWlPQVVjTHpQUUtZRUdTNEtZbjVMcnM0NWhLX1hYalFTRUFWekxiSzU1MWxUbHNZR0hnQnl0VWdSMERFUUdyWlo2M05HQ0s0LU9MNEd0eGNwdzZKUnhGTjZkMVptbk9XNWV5UTBiVk9iMTBrRkxsNzY3TGwxQzZyRk1BdmNuN2s2eG9jOU8yeWRlY2RZLVZPb3NUNFVB; YSC=HdKkKXvbFwM; wide=1; SID=g.a000-Qg4rXgNdBh9s83Ml3duKJ8RJZH_c5qDJ7tGk55rjwxe2zoSUsr1qFd9xeM62WZclxEV5gACgYKAY8SARASFQHGX2MiOirevBuW1MiwTkEjn5nnyBoVAUF8yKoaWSLV5WirUdyufzA6GwS20076; __Secure-1PSID=g.a000-Qg4rXgNdBh9s83Ml3duKJ8RJZH_c5qDJ7tGk55rjwxe2zoSqNCHqW3bFkd6MTM-11acdAACgYKAU0SARASFQHGX2Mi8R_jmJwfX2XdQ-Z3r7f6UhoVAUF8yKpCwUg2zUatAGbPepbSjpgP0076; __Secure-3PSID=g.a000-Qg4rXgNdBh9s83Ml3duKJ8RJZH_c5qDJ7tGk55rjwxe2zoS3LGF4SiPUiACxCa3AepM3gACgYKAQ0SARASFQHGX2Mi2QSlf7e4BGzL9XUaCgrP7hoVAUF8yKoreEdRSE5zLiMnMErgorhx0076; __Secure-YNID=18.YT=kOZ0-EjBzCMHkXCzTV4VLJg-JGisqHHqA2JBf0gyfbH1-S0m0cqRXebaaNOhlVFOXASz_wmwLKsvbTF6Rnv4WKwuvlvlK4eruZDC8UZjI29N0kdh1_Gxb74bQkOulHNHOiYEzof1JjeMCv-PzXstMB8k_uVUnI8aPow3SjALTAlPbvUsMCx8KZLw45pi775YR9PDS_S2nFIM1cuWV2fV-BDT2C3nHwx3YvbtmiiW_tVH2lyWnPexxpURd7gjyTRlA4K7plV3SdIjzvUyDeHc9N-HsCttbH1G4zk-HRjFYiLwg37Z9gSZxb9QNj0XXzQDrE7CumfTtl5yAhp37s4zYQ; __Secure-ROLLOUT_TOKEN=CJq95KGs8NnaWxCO7vOh8eeNAxiJmrPVgdiUAw%3D%3D; __Secure-1PSIDTS=sidts-CjQBhkeRd3qgz-LeWAiS9NsBkiDvuGuzlZOspuM6Dv_sW0c2oIw9Ip32akfRChsE2RJqgPWgEAA; __Secure-3PSIDTS=sidts-CjQBhkeRd3qgz-LeWAiS9NsBkiDvuGuzlZOspuM6Dv_sW0c2oIw9Ip32akfRChsE2RJqgPWgEAA; SIDCC=AKEyXzUAqZUCX4yVhd7h7NRX23SAAFM1O6TRj33DB89RTJew-6ceWZnxID-T0HnS3hMPchdbUR2O; __Secure-1PSIDCC=AKEyXzVUwnwpTJgFFTwgT3Ts_h7fAB-hHDh5eSWS-QXYVKB63nwbDeWRR2LfeX4eNcfLOyuNgoek; __Secure-3PSIDCC=AKEyXzWNmkBdLWavBqMz-T7nbaFa78-pnvG8vCG1Cc7KTht4id3-OY2uLYT5hKjkKE-gV1C7RvY; ST-l3hjtt=session_logininfo=AFmmF2swRQIhAMamKrjFjya7Es-vOkq1j72SrtJs0ol1lD5TcMwjYa2uAiAPttAeK26z45j010g3hQeUiBmyx0JX4wBMXTLdQINmfA%3AQUQ3MjNmeUF5ay01bWlPQVVjTHpQUUtZRUdTNEtZbjVMcnM0NWhLX1hYalFTRUFWekxiSzU1MWxUbHNZR0hnQnl0VWdSMERFUUdyWlo2M05HQ0s0LU9MNEd0eGNwdzZKUnhGTjZkMVptbk9XNWV5UTBiVk9iMTBrRkxsNzY3TGwxQzZyRk1BdmNuN2s2eG9jOU8yeWRlY2RZLVZPb3NUNFVB';
}

class UserAgentHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final String Function()? getCookies;

  UserAgentHttpClient({this.getCookies});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';
    request.headers['Accept-Language'] = 'en-US,en;q=0.9,es-ES;q=0.8,es;q=0.7';
    request.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8';
    request.headers['Sec-Ch-Ua'] = '"Chromium";v="123", "Not:A-Brand";v="8"';
    request.headers['Sec-Ch-Ua-Mobile'] = '?0';
    request.headers['Sec-Ch-Ua-Platform'] = '"Windows"';
    request.headers['Upgrade-Insecure-Requests'] = '1';

    var cookies = getCookies?.call();
    if (cookies == null || cookies.isEmpty) {
      cookies = _globalGuestCookies;
    }

    if (cookies != null && cookies.isNotEmpty) {
      request.headers['Cookie'] = cookies;
      if (request.url.host.contains('youtube.com') || request.url.host.contains('youtu.be')) {
        print('DEBUG_YT: [COOKIES] Inyectando cookies para: ${request.url}');
      }
    }

    return _inner.send(request);
  }
}

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
  failed, // Descarga fallida
}

class DownloadState {
  final double progress;
  final YouTubeVideoResult video;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final List<String> logs;
  final String? errorMessage;

  DownloadState({
    required this.progress,
    required this.video,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    this.logs = const [],
    this.errorMessage,
  });

  DownloadState copyWith({
    double? progress,
    YouTubeVideoResult? video,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    List<String>? logs,
    String? errorMessage,
  }) {
    return DownloadState(
      progress: progress ?? this.progress,
      video: video ?? this.video,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      logs: logs ?? this.logs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

@riverpod
class YouTubeSearch extends _$YouTubeSearch {
  late final _yt = YoutubeExplode(
    httpClient: YoutubeHttpClient(
      UserAgentHttpClient(
        getCookies: () => ref.read(settingsProvider).youtubeCookies,
      ),
    ),
  );

  @override
  FutureOr<YouTubeSearchResult> build() {
    ref.onDispose(() {
      _yt.close();
    });
    return YouTubeSearchResult(videos: [], isPlaylist: false);
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = AsyncValue.data(
        YouTubeSearchResult(videos: [], isPlaylist: false),
      );
      return;
    }

    final manualCookies = ref.read(settingsProvider).youtubeCookies;
    if (manualCookies.isEmpty && _globalGuestCookies == null) {
      _globalGuestCookies = await _fetchGuestCookies();
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
}

@riverpod
class YouTubeDownload extends _$YouTubeDownload {
  late final _yt = YoutubeExplode(
    httpClient: YoutubeHttpClient(
      UserAgentHttpClient(
        getCookies: () => ref.read(settingsProvider).youtubeCookies,
      ),
    ),
  );

  @override
  DownloadState? build() {
    ref.onDispose(() {
      _yt.close();
    });
    return null; // null if not downloading
  }

  void clear() {
    state = null;
  }

  void _addLog(String message) {
    print('DEBUG_YT: $message');
    if (state != null) {
      state = state!.copyWith(logs: [...state!.logs, message]);
    }
  }

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
    final globalStopwatch = Stopwatch()..start();
    final stepStopwatch = Stopwatch()..start();
    
    final initialLog = '[INICIO] Comenzando proceso de descarga para el video: "${video.title}" (ID: ${video.id})';
    print('DEBUG_YT: $initialLog');

    try {
      final manualCookies = ref.read(settingsProvider).youtubeCookies;
      if (manualCookies.isEmpty && _globalGuestCookies == null) {
        _globalGuestCookies = await _fetchGuestCookies();
      }

      state = DownloadState(
        progress: 0.0,
        video: video,
        totalBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.analyzing,
        logs: [initialLog],
      );

      // 1. Solicitar permisos y preparar directorios
      _addLog('[1/7] Solicitando permisos de almacenamiento...');
      await ref.read(musicLibraryProvider.notifier).requestStoragePermission();
      _addLog('[1/7] Permisos resueltos en ${stepStopwatch.elapsedMilliseconds} ms.');
      stepStopwatch.reset();

      // Preparar ruta y nombres compartidos
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
        _addLog('[PREPARACIÓN] Creando directorio: $downloadPath');
        await directory.create(recursive: true);
        _addLog('[PREPARACIÓN] Directorio creado en ${stepStopwatch.elapsedMilliseconds} ms.');
      }
      stepStopwatch.reset();

      final parsed = _parseVideoTitle(video.title, video.author);
      final artist = parsed['artist']!;
      final title = parsed['title']!;
      final fileName = '$artist - $title'
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .trim();

      // 2. Verificar si podemos leer detalles del video primero (útil para la miniatura de alta resolución)
      Video? fullVideo;
      try {
        _addLog('[2/7] Solicitando información extendida del video a YouTube...');
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
        _addLog('[2/7] Información obtenida correctamente en ${stepStopwatch.elapsedMilliseconds} ms.');
      } catch (e) {
        _addLog('[2/7] Error obteniendo info del video tras ${stepStopwatch.elapsedMilliseconds} ms: $e');
        _addLog('Usando la información básica del video como respaldo.');
        fullVideo = null;
      }
      stepStopwatch.reset();

      // Variables de control de descarga
      String extension = 'mp3';
      int totalAudioBytes = 0;

      // --- DESCARGA CON YOUTUBE EXPLODE DART ---
      _addLog('[3/7] Obteniendo manifest de streams con youtube_explode_dart...');
      state = state!.copyWith(
        progress: 0.0,
        status: DownloadStatus.fetchingManifest,
      );

      StreamManifest? manifest;
      final errors = <String>[];

      final clientConfigs = [
        [YoutubeApiClient.androidVr],
        [YoutubeApiClient.ios, YoutubeApiClient.safari],
        [YoutubeApiClient.tv],
        null,
      ];

      for (var i = 0; i < clientConfigs.length; i++) {
        final config = clientConfigs[i];
        final configDesc = config == null
            ? 'Por defecto'
            : config.map((c) {
                if (c == YoutubeApiClient.androidVr) return 'androidVr';
                if (c == YoutubeApiClient.ios) return 'ios';
                if (c == YoutubeApiClient.safari) return 'safari';
                if (c == YoutubeApiClient.tv) return 'tv';
                return c.toString();
              }).join('+');
        _addLog('[DESCARGA] Intentando obtener manifiesto con clientes: $configDesc (Intento ${i + 1}/${clientConfigs.length})...');
        
        stepStopwatch.reset();
        try {
          if (config == null) {
            manifest = await _yt.videos.streams
                .getManifest(video.id)
                .timeout(const Duration(seconds: 15));
          } else {
            manifest = await _yt.videos.streams
                .getManifest(video.id, ytClients: config)
                .timeout(const Duration(seconds: 15));
          }
          _addLog('[DESCARGA] Manifiesto obtenido con éxito en ${stepStopwatch.elapsedMilliseconds} ms usando clientes: $configDesc');
          break;
        } catch (e) {
          _addLog('[DESCARGA] Falló el intento con clientes $configDesc tras ${stepStopwatch.elapsedMilliseconds} ms: $e');
          errors.add('$configDesc: $e');
        }
      }
      stepStopwatch.reset();

      if (manifest == null) {
        throw Exception(
          'YouTube está bloqueando la solicitud de descarga (Intento fallido con todos los clientes).\n'
          'Detalles de los errores:\n${errors.join('\n')}'
        );
      }

      state = state!.copyWith(
        progress: 0.0,
        status: DownloadStatus.selectingQuality,
      );

      final audioStreams = manifest.audioOnly.where(
        (s) => s.container.name == 'mp4',
      );
      final audioStream = audioStreams.isNotEmpty
          ? audioStreams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      extension = audioStream.container.name == 'mp4'
          ? 'm4a'
          : audioStream.container.name;
          
      final ytFile = File('${directory.path}/$fileName.$extension');
      totalAudioBytes = audioStream.size.totalBytes;

      state = state!.copyWith(
        progress: 0.0,
        totalBytes: totalAudioBytes,
        status: DownloadStatus.downloading,
      );

      _addLog('[DESCARGA] Obteniendo stream de YoutubeExplode. Stream size: ${audioStream.size.totalBytes} bytes');
      stepStopwatch.reset();
      final stream = _yt.videos.streams.get(audioStream);

      _addLog('[DESCARGA] Abriendo archivo para escritura...');
      final fileStream = ytFile.openWrite();
      int downloadedBytes = 0;

      try {
        _addLog('[DESCARGA] Escuchando chunks del stream...');
        await for (final chunk in stream.timeout(
          const Duration(seconds: 15),
          onTimeout: (sink) {
            _addLog('[DESCARGA] Timeout del stream detectado durante la descarga (sin datos recibidos por 15s)');
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
              (downloadedBytes / totalAudioBytes).clamp(0.0, 1.0);

          if (downloadedBytes == chunk.length) {
            _addLog('[DESCARGA] Primer chunk recibido (${chunk.length} bytes) en ${stepStopwatch.elapsedMilliseconds} ms.');
          }

          state = state!.copyWith(
            progress: currentProgress,
            downloadedBytes: downloadedBytes,
            status: currentProgress < 0.95
                ? DownloadStatus.downloading
                : DownloadStatus.finalizing,
          );
        }
        
        _addLog('[DESCARGA] Transferencia completada. Total: $downloadedBytes bytes en ${stepStopwatch.elapsedMilliseconds} ms (~${(downloadedBytes / 1024 / (stepStopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(2)} KB/s).');
        
        stepStopwatch.reset();
        await fileStream.flush();
        await fileStream.close();
        _addLog('[DESCARGA] Guardado en disco finalizado en ${stepStopwatch.elapsedMilliseconds} ms.');
      } catch (e) {
        _addLog('[DESCARGA] Excepción durante la descarga del stream tras ${stepStopwatch.elapsedMilliseconds} ms: $e');
        await fileStream.close();
        if (await ytFile.exists()) {
          await ytFile.delete();
        }
        throw Exception('Error al descargar el audio: $e');
      }

      // --- PROCEDIMIENTO POST-DESCARGA (MINIATURA, METADATOS, ESCANEO) ---
      if (extension != 'm4a') {
        // Descargar miniatura (Mejor resolución real posible)
        _addLog('[5/7] Iniciando descarga de miniatura...');
        state = state!.copyWith(
          progress: 0.0,
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
            _addLog('[MINIATURA] Probando URL de miniatura: $url');
            stepStopwatch.reset();
            try {
              final response = await http
                  .get(Uri.parse(url))
                  .timeout(const Duration(seconds: 10));
              
              _addLog('[MINIATURA] Respuesta recibida en ${stepStopwatch.elapsedMilliseconds} ms (Status: ${response.statusCode}).');
              if (response.statusCode == 200) {
                if (response.bodyBytes.length > 5000) {
                  bestImageBytes = response.bodyBytes;
                  _addLog('[MINIATURA] Miniatura obtenida correctamente con tamaño: ${bestImageBytes.length} bytes.');
                  break;
                } else {
                  _addLog('[MINIATURA] Miniatura demasiado pequeña: ${response.bodyBytes.length} bytes.');
                }
              } else {
                _addLog('[MINIATURA] Error HTTP en miniatura: ${response.statusCode}');
              }
            } catch (e) {
              _addLog('[MINIATURA] Error obteniendo miniatura tras ${stepStopwatch.elapsedMilliseconds} ms: $e');
            }
          }

          stepStopwatch.reset();
          if (bestImageBytes != null) {
            final thumbnailFile = File('${directory.path}/$fileName.jpg');
            await thumbnailFile.writeAsBytes(bestImageBytes);
            _addLog('[MINIATURA] Miniatura guardada en disco en ${stepStopwatch.elapsedMilliseconds} ms.');
          }
        } catch (e) {
          _addLog('[MINIATURA] Error global en descarga de miniatura: $e');
        }
        stepStopwatch.reset();

        // Guardar metadatos usando audio_metadata_reader (AMR)
        try {
          if (_isSafeToModifyMetadata(ytFile)) {
            _addLog('[6/7] Iniciando inserción de metadatos (AMR)...');
            state = state!.copyWith(
              progress: 0.98,
              status: DownloadStatus.writingMetadata,
            );

            final thumbnailFile = File('${directory.path}/$fileName.jpg');
            Uint8List? artworkBytes;

            if (await thumbnailFile.exists()) {
              final originalBytes = await thumbnailFile.readAsBytes();
              _addLog('[METADATOS] Iniciando compresión de carátula (${originalBytes.length} bytes)...');
              stepStopwatch.reset();
              artworkBytes = await _compressArtwork(originalBytes);
              _addLog('[METADATOS] Carátula comprimida en ${stepStopwatch.elapsedMilliseconds} ms (Nuevo tamaño: ${artworkBytes?.length} bytes).');
            }

            // Aplicar metadatos usando AMR
            try {
              stepStopwatch.reset();
              amr.updateMetadata(ytFile, (metadata) {
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
              _addLog('[METADATOS] Metadatos actualizados con éxito vía AMR en ${stepStopwatch.elapsedMilliseconds} ms.');
            } catch (e) {
              _addLog('[METADATOS] Error actualizando metadatos con AMR: $e');
            }

            // Limpiar miniatura temporal
            stepStopwatch.reset();
            if (await thumbnailFile.exists()) {
              await thumbnailFile.delete();
              _addLog('[METADATOS] Miniatura temporal eliminada en ${stepStopwatch.elapsedMilliseconds} ms.');
            }
          } else {
            _addLog('[6/7] Omitiendo inserción de metadatos (archivo inseguro o demasiado grande).');
          }
        } catch (e) {
          _addLog('[METADATOS] Error global en procesamiento de metadatos: $e');
        }
      }
      stepStopwatch.reset();

      // Notificar MediaStore (Solo en Android, ya que on_audio_query no tiene implementación en escritorio)
      if (Platform.isAndroid) {
        try {
          final audioQuery = OnAudioQuery();
          await audioQuery.scanMedia(ytFile.path);
          _addLog('[ESCANEO] Escaneo MediaStore completado en ${stepStopwatch.elapsedMilliseconds} ms.');
        } catch (e) {
          _addLog('[ESCANEO] Error escaneando MediaStore: $e');
        }
      } else {
        _addLog('[ESCANEO] Omitiendo escaneo de MediaStore (No soportado en esta plataforma).');
      }
      stepStopwatch.reset();

      state = null;
      await Future.delayed(const Duration(seconds: 1));
      
      _addLog('[ESCANEO] Escaneando música del dispositivo con musicLibraryProvider...');
      await ref.read(musicLibraryProvider.notifier).scanDeviceMusic();
      _addLog('[ESCANEO] Escaneo de biblioteca completado en ${stepStopwatch.elapsedMilliseconds} ms.');

      globalStopwatch.stop();
      _addLog('[COMPLETADO] Descarga y procesamiento finalizados con éxito en ${globalStopwatch.elapsedMilliseconds} ms (~${(globalStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} segundos).');

      return ytFile.path;
    } catch (e) {
      globalStopwatch.stop();
      _addLog('[ERROR] Descarga falló después de ${globalStopwatch.elapsedMilliseconds} ms con error: $e');
      if (state != null) {
        state = state!.copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
      }
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
}
