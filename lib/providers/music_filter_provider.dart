import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/music_library_provider.dart';

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
List<MusicTrack> filteredSongs(Ref ref) {
  final musicLibrary = ref.watch(musicLibraryProvider);
  final searchQuery = ref.watch(musicSearchQueryProvider).toLowerCase();
  final selectedCategory = ref.watch(selectedCategoryProvider);

  return musicLibrary.where((song) {
    // 1. Filtrar por categoría
    if (selectedCategory == 'Favoritas' && !song.isFavorite) {
      return false;
    }

    // Aquí puedes añadir más categorías en el futuro:
    // if (selectedCategory == 'Recientes') ...

    // 2. Filtrar por búsqueda
    if (searchQuery.isEmpty) return true;

    return song.title.toLowerCase().contains(searchQuery) ||
        song.artist.toLowerCase().contains(searchQuery);
  }).toList();
}
