import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/providers/playlist_provider.dart';

part 'music_filter_provider.g.dart';

@riverpod
class MusicSearchQuery extends _$MusicSearchQuery {
  @override
  String build() => '';

  void update(String query) => state = query;
  void clear() => state = '';
}

@riverpod
class SelectedCategory extends _$SelectedCategory {
  @override
  String build() => 'Todas';

  void update(String category) => state = category;
}

@riverpod
List<MusicTrack> recentDownloads(Ref ref) {
  final musicLibrary = ref.watch(musicLibraryProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  const maxAgeMs = 24 * 60 * 60 * 1000; // 24 horas

  // Filtrar solo las canciones descargadas en las últimas 24 horas
  final recent = musicLibrary.where((song) {
    if (!song.isDownloaded) return false;
    final date = song.dateAdded;
    if (date == null) return false;
    return (now - date) < maxAgeMs;
  }).toList();

  recent.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
  return recent.take(5).toList();
}

@riverpod
List<MusicTrack> filteredSongs(Ref ref) {
  final musicLibrary = ref.watch(musicLibraryProvider);
  final searchQuery = ref.watch(musicSearchQueryProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final now = DateTime.now().millisecondsSinceEpoch;
  const maxAgeMs = 24 * 60 * 60 * 1000; // 24 horas

  if (selectedCategory == 'Descargas') {
    // Solo las canciones descargadas en las últimas 24 horas (máximo 5)
    final downloaded = musicLibrary.where((song) {
      if (!song.isDownloaded) return false;
      final date = song.dateAdded;
      // Si tiene fecha y tiene más de 24 horas, expira
      if (date != null && (now - date) > maxAgeMs) {
        return false;
      }
      if (searchQuery.isEmpty) return true;
      return song.title.toLowerCase().contains(searchQuery) ||
          song.artist.toLowerCase().contains(searchQuery);
    }).toList();

    downloaded.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    return downloaded.take(5).toList();
  }

  if (selectedCategory.startsWith('playlist:')) {
    final playlistId = selectedCategory.replaceFirst('playlist:', '');
    final playlistTracks = ref.watch(playlistSongsProvider(playlistId));
    if (searchQuery.isEmpty) return playlistTracks;
    return playlistTracks.where((song) {
      return song.title.toLowerCase().contains(searchQuery) ||
          song.artist.toLowerCase().contains(searchQuery);
    }).toList();
  }

  final list = musicLibrary.where((song) {
    // 1. Filtrar por categoría
    if (selectedCategory == 'Favoritas' && !song.isFavorite) {
      return false;
    }

    // 2. Filtrar por búsqueda
    if (searchQuery.isEmpty) return true;

    return song.title.toLowerCase().contains(searchQuery) ||
        song.artist.toLowerCase().contains(searchQuery);
  }).toList();

  return list;
}

