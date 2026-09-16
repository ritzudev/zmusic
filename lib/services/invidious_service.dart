import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InvidiousSong {
  final String id;
  final String title;
  final String author;
  final int durationSeconds;
  final String thumbnailUrl;

  const InvidiousSong({
    required this.id,
    required this.title,
    required this.author,
    required this.durationSeconds,
    required this.thumbnailUrl,
  });

  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class InvidiousAudioStreamInfo {
  final String url;
  final String container; // 'm4a' o 'webm'
  final int bitrate;
  final int? totalBytes;

  const InvidiousAudioStreamInfo({
    required this.url,
    required this.container,
    required this.bitrate,
    this.totalBytes,
  });
}

class InvidiousService {
  static const List<String> _instances = [
    'https://inv.nadeko.net',
    'https://yewtu.be',
  ];

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  /// Busca videos en YouTube a través de Invidious con fallback de instancias
  static Future<List<InvidiousSong>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final cleanQuery = Uri.encodeComponent(query.trim());

    for (final base in _instances) {
      try {
        final url = Uri.parse('$base/api/v1/search?q=$cleanQuery&type=video');
        final response = await http.get(
          url,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          final List<InvidiousSong> songs = [];

          for (final item in data) {
            if (item is! Map) continue;
            final videoId = item['videoId']?.toString() ?? '';
            if (videoId.isEmpty) continue;

            final title = _unescapeHtml(item['title']?.toString() ?? 'Sin título');
            final author = _unescapeHtml(item['author']?.toString() ?? 'YouTube');
            final duration = int.tryParse(item['lengthSeconds']?.toString() ?? '0') ?? 0;

            final thumbnail = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

            songs.add(
              InvidiousSong(
                id: videoId,
                title: title,
                author: author,
                durationSeconds: duration,
                thumbnailUrl: thumbnail,
              ),
            );
          }
          return songs;
        }
      } catch (e) {
        debugPrint('DEBUG_INVIDIOUS: Error buscando en $base: $e');
      }
    }
    return [];
  }

  /// Obtiene el mejor stream de audio para un video específico
  static Future<InvidiousAudioStreamInfo?> getAudioStream(String videoId) async {
    for (final base in _instances) {
      try {
        final url = Uri.parse('$base/api/v1/videos/$videoId');
        final response = await http.get(
          url,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final formats = data['adaptiveFormats'] as List? ?? [];

          // Filtrar streams de audio
          final audioFormats = formats.where((f) {
            final type = (f['type'] ?? '').toString();
            return type.startsWith('audio/');
          }).toList();

          if (audioFormats.isEmpty) continue;

          Map selectedAudio = audioFormats.first as Map;
          for (final f in audioFormats) {
            if (f is! Map) continue;
            final itag = f['itag']?.toString();
            final type = (f['type'] ?? '').toString();
            if (itag == '140' || type.contains('audio/mp4')) {
              selectedAudio = f;
              break;
            }
          }

          final streamUrl = selectedAudio['url']?.toString() ?? '';
          if (streamUrl.isEmpty) continue;

          final type = (selectedAudio['type'] ?? '').toString();
          final container = type.contains('audio/mp4') || selectedAudio['itag']?.toString() == '140'
              ? 'm4a'
              : 'webm';

          final bitrate = int.tryParse(selectedAudio['bitrate']?.toString() ?? '0') ?? 0;
          final clen = selectedAudio['clen']?.toString();
          final totalBytes = clen != null ? int.tryParse(clen) : null;

          return InvidiousAudioStreamInfo(
            url: streamUrl,
            container: container,
            bitrate: bitrate,
            totalBytes: totalBytes,
          );
        }
      } catch (e) {
        debugPrint('DEBUG_INVIDIOUS: Error obteniendo video $videoId en $base: $e');
      }
    }
    return null;
  }
}
