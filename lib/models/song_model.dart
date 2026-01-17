class MusicTrack {
  final String id;
  final int songId;
  final int? albumId;
  final String title;
  final String artist;
  final String filePath;
  final String? albumArt;
  final Duration? duration;
  final String? album;
  final int? size;
  final bool isFavorite;

  MusicTrack({
    required this.id,
    required this.songId,
    this.albumId,
    required this.title,
    required this.artist,
    required this.filePath,
    this.albumArt,
    this.duration,
    this.album,
    this.size,
    this.isFavorite = false,
  });

  MusicTrack copyWith({
    String? id,
    int? songId,
    int? albumId,
    String? title,
    String? artist,
    String? filePath,
    String? albumArt,
    Duration? duration,
    String? album,
    int? size,
    bool? isFavorite,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      albumId: albumId ?? this.albumId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      filePath: filePath ?? this.filePath,
      albumArt: albumArt ?? this.albumArt,
      duration: duration ?? this.duration,
      album: album ?? this.album,
      size: size ?? this.size,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // Obtener la primera letra del título para el AlphabetListView
  String get firstLetter {
    return title.isNotEmpty ? title[0].toUpperCase() : '#';
  }

  // Formatear la duración
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Convertir a JSON para caché
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'songId': songId,
      'albumId': albumId,
      'title': title,
      'artist': artist,
      'filePath': filePath,
      'albumArt': albumArt,
      'durationMs': duration?.inMilliseconds,
      'album': album,
      'size': size,
      'isFavorite': isFavorite,
    };
  }

  // Crear desde JSON
  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] as String,
      songId: json['songId'] as int,
      albumId: json['albumId'] as int?,
      title: json['title'] as String,
      artist: json['artist'] as String,
      filePath: json['filePath'] as String,
      albumArt: json['albumArt'] as String?,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      album: json['album'] as String?,
      size: json['size'] as int?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
