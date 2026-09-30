import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentDownloadItem {
  final String id;
  final String title;
  final String artist;
  final String filePath;
  final int downloadedAt;

  RecentDownloadItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'filePath': filePath,
        'downloadedAt': downloadedAt,
      };

  factory RecentDownloadItem.fromJson(Map<String, dynamic> json) =>
      RecentDownloadItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        filePath: json['filePath'] as String? ?? '',
        downloadedAt: json['downloadedAt'] as int? ?? 0,
      );
}

class RecentDownloadsService {
  static const String _key = 'recent_downloads_history_v1';
  static const int maxItems = 5;
  static const int expireHours = 24;

  static Future<void> recordDownload({
    required String id,
    required String title,
    required String artist,
    required String filePath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getValidRecentDownloads();

      list.removeWhere(
        (item) =>
            item.id == id ||
            item.filePath.toLowerCase() == filePath.toLowerCase(),
      );

      list.insert(
        0,
        RecentDownloadItem(
          id: id,
          title: title,
          artist: artist,
          filePath: filePath,
          downloadedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final trimmed = list.take(maxItems).toList();
      final jsonList = trimmed.map((e) => e.toJson()).toList();
      await prefs.setString(_key, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<List<RecentDownloadItem>> getValidRecentDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];

      final List decoded = jsonDecode(raw);
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAgeMs = expireHours * 60 * 60 * 1000;

      final validItems = <RecentDownloadItem>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final parsed = RecentDownloadItem.fromJson(item);
          // Solo mantener si fue descargado hace menos de 24 horas
          if (now - parsed.downloadedAt < maxAgeMs) {
            validItems.add(parsed);
          }
        }
      }

      if (validItems.length != decoded.length) {
        final jsonList = validItems.map((e) => e.toJson()).toList();
        await prefs.setString(_key, jsonEncode(jsonList));
      }

      return validItems.take(maxItems).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
