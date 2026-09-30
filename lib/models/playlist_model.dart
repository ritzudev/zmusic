class PlaylistModel {
  final String id;
  final String name;
  final List<String> songIds;
  final int createdAt;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
  });

  PlaylistModel copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    int? createdAt,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songIds': songIds,
      'createdAt': createdAt,
    };
  }

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    return PlaylistModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Mi lista',
      songIds: (json['songIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
