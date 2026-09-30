import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zmusic/models/playlist_model.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/music_library_provider.dart';

class PlaylistNotifier extends Notifier<List<PlaylistModel>> {
  static const String _storageKey = 'user_custom_playlists_v1';

  @override
  List<PlaylistModel> build() {
    _loadPlaylists();
    return [];
  }

  Future<void> _loadPlaylists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List decoded = jsonDecode(raw);
        final playlists = decoded
            .map((item) => PlaylistModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = playlists;
      }
    } catch (_) {}
  }

  Future<void> _savePlaylists(List<PlaylistModel> playlists) async {
    state = playlists;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = playlists.map((p) => p.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<PlaylistModel> createPlaylist(String name, {List<String>? initialSongIds}) async {
    final cleanName = name.trim().isEmpty ? 'Nueva Lista' : name.trim();
    final newPlaylist = PlaylistModel(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}_${state.length + 1}',
      name: cleanName,
      songIds: initialSongIds ?? [],
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final updated = [newPlaylist, ...state];
    await _savePlaylists(updated);
    return newPlaylist;
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;

    final updated = state.map((p) {
      if (p.id == playlistId) {
        return p.copyWith(name: cleanName);
      }
      return p;
    }).toList();

    await _savePlaylists(updated);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final updated = state.where((p) => p.id != playlistId).toList();
    await _savePlaylists(updated);
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final updated = state.map((p) {
      if (p.id == playlistId) {
        if (!p.songIds.contains(songId)) {
          return p.copyWith(songIds: [...p.songIds, songId]);
        }
      }
      return p;
    }).toList();

    await _savePlaylists(updated);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final updated = state.map((p) {
      if (p.id == playlistId) {
        return p.copyWith(
          songIds: p.songIds.where((id) => id != songId).toList(),
        );
      }
      return p;
    }).toList();

    await _savePlaylists(updated);
  }

  Future<void> toggleSongInPlaylist(String playlistId, String songId) async {
    final playlist = state.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => PlaylistModel(id: '', name: '', songIds: [], createdAt: 0),
    );
    if (playlist.id.isEmpty) return;

    if (playlist.songIds.contains(songId)) {
      await removeSongFromPlaylist(playlistId, songId);
    } else {
      await addSongToPlaylist(playlistId, songId);
    }
  }

  Future<void> reorderSongs(String playlistId, int oldIndex, int newIndex) async {
    final updated = state.map((p) {
      if (p.id == playlistId) {
        final list = List<String>.from(p.songIds);
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        return p.copyWith(songIds: list);
      }
      return p;
    }).toList();

    await _savePlaylists(updated);
  }
}

final playlistProvider =
    NotifierProvider<PlaylistNotifier, List<PlaylistModel>>(
  PlaylistNotifier.new,
);

// Provider auxiliar que obtiene las canciones completas (MusicTrack) de una playlist
final playlistSongsProvider =
    Provider.family<List<MusicTrack>, String>((ref, playlistId) {
  final playlists = ref.watch(playlistProvider);
  final library = ref.watch(musicLibraryProvider);

  final playlist = playlists.firstWhere(
    (p) => p.id == playlistId,
    orElse: () => PlaylistModel(id: '', name: '', songIds: [], createdAt: 0),
  );

  if (playlist.id.isEmpty || playlist.songIds.isEmpty) return [];

  final songMap = {for (final s in library) s.id: s};
  final List<MusicTrack> tracks = [];

  for (final songId in playlist.songIds) {
    final track = songMap[songId];
    if (track != null) {
      tracks.add(track);
    }
  }

  return tracks;
});
