import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_filter_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/providers/theme_provider.dart';
import 'package:zmusic/screens/now_playing_screen.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/music_player_controls.dart';

class MusicHomeScreen extends ConsumerStatefulWidget {
  const MusicHomeScreen({super.key});

  @override
  ConsumerState<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends ConsumerState<MusicHomeScreen> {
  bool _isLoading = true;
  String _loadingMessage = 'Escaneando música...';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Verificar caché después de que el widget esté completamente construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCacheAndScan();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkCacheAndScan() async {
    final notifier = ref.read(musicLibraryProvider.notifier);

    // Asegurar que tenemos permisos antes de intentar procesar música o artworks
    await notifier.requestStoragePermission();

    final hasCached = await notifier.hasCachedData();

    if (!hasCached) {
      // Solo escanear si no hay datos en caché
      await _scanMusic();
    } else {
      // Si hay caché, simplemente ocultar el loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanMusic() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Escaneando música...';
    });

    final notifier = ref.read(musicLibraryProvider.notifier);
    final result = await notifier.scanDeviceMusic();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _playRandomSong() async {
    final filteredSongs = ref.read(filteredSongsProvider);

    if (filteredSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay canciones disponibles')),
      );
      return;
    }

    // Generar un índice aleatorio
    final randomIndex =
        (filteredSongs.length * DateTime.now().millisecond / 1000).floor() %
        filteredSongs.length;

    // Reproducir la canción aleatoria
    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    await playerNotifier.setPlaylistAndPlay(
      filteredSongs,
      initialIndex: randomIndex,
    );

    // Mostrar mensaje
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reproduciendo: ${filteredSongs[randomIndex].title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredSongsList = ref.watch(filteredSongsProvider);
    final searchQuery = ref.watch(musicSearchQueryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Z",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextFormField(
                            controller: _searchController,
                            onChanged: (value) {
                              ref
                                  .read(musicSearchQueryProvider.notifier)
                                  .update(value);
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(
                                              musicSearchQueryProvider.notifier,
                                            )
                                            .clear();
                                      },
                                    )
                                  : null,
                              hintText: "Buscar música",
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón de descarga de YouTube
                      /* Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/youtube-search');
                          },
                          icon: const Icon(Icons.download_rounded),
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón de cambio de tema
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            ref.read(themeProvider.notifier).toggleTheme();
                          },
                          icon: Icon(
                            theme.brightness == Brightness.dark
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: theme.brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ), */
                      const SizedBox(width: 8),
                      // Botón Debug (Metadatos)
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/tagger-test');
                          },
                          icon: const Icon(
                            Icons.bug_report,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Mi Música",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        "${filteredSongsList.length} canciones",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: "Todas",
                          isSelected: selectedCategory == "Todas",
                          onTap: () => ref
                              .read(selectedCategoryProvider.notifier)
                              .update("Todas"),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: "Favoritas",
                          isSelected: selectedCategory == "Favoritas",
                          onTap: () => ref
                              .read(selectedCategoryProvider.notifier)
                              .update("Favoritas"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _loadingMessage,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Esto puede tomar unos segundos...",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredSongsList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selectedCategory == 'Favoritas'
                                ? Icons.favorite_border_rounded
                                : Icons.search_off_rounded,
                            size: 80,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            selectedCategory == 'Favoritas'
                                ? "No tienes canciones favoritas"
                                : (searchQuery.isEmpty
                                      ? "No se encontró música"
                                      : "No hay resultados para '$searchQuery'"),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedCategory == 'Favoritas'
                                ? "Toca el corazón en tus canciones preferidas para verlas aquí"
                                : (searchQuery.isEmpty
                                      ? "Toca el botón de refrescar para volver a escanear"
                                      : "Intenta con otro término de búsqueda"),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.4,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 100, // Espacio para el mini player
                      ),
                      itemCount: filteredSongsList.length,
                      itemBuilder: (context, index) {
                        return _MusicCard(
                          song: filteredSongsList[index],
                          index: index,
                          filteredPlaylist: filteredSongsList,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'shuffle_button',
            onPressed: _isLoading ? null : _playRandomSong,
            tooltip: 'Reproducir música aleatoria',
            child: const Icon(Icons.shuffle),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'refresh_button',
            onPressed: _isLoading ? null : _scanMusic,
            tooltip: 'Refrescar biblioteca',
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini player
            Consumer(
              builder: (context, ref, child) {
                final playerState = ref.watch(audioPlayerProvider);
                if (playerState.currentTrack == null) {
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const NowPlayingScreen(),
                        transitionDuration: const Duration(milliseconds: 500),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 500,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              const curve = Curves.fastOutSlowIn;
                              final curvedAnimation = CurvedAnimation(
                                parent: animation,
                                curve: curve,
                                reverseCurve: curve,
                              );
                              return FadeTransition(
                                opacity: curvedAnimation,
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                  child: const MusicPlayerControls(showMiniPlayer: true),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CategoryChip({
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (theme.brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white)
                : theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MusicCard extends ConsumerWidget {
  final MusicTrack song;
  final int index;
  final List<MusicTrack>? filteredPlaylist;

  const _MusicCard({
    required this.song,
    required this.index,
    this.filteredPlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCurrentSong = ref.watch(
      audioPlayerProvider.select((s) => s.currentTrack?.id == song.id),
    );
    final isPlaying = ref.watch(
      audioPlayerProvider.select(
        (s) => s.currentTrack?.id == song.id && s.isPlaying,
      ),
    );

    return InkWell(
      onTap: () async {
        final List<MusicTrack> playlist =
            filteredPlaylist ?? ref.read(musicLibraryProvider);
        final playerNotifier = ref.read(audioPlayerProvider.notifier);

        if (isCurrentSong) {
          // Si es la canción actual, solo alternar play/pause
          await playerNotifier.togglePlayPause();
        } else {
          // Si es una canción diferente, establecer la playlist y reproducir
          await playerNotifier.setPlaylistAndPlay(
            playlist,
            initialIndex: index,
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ArtworkWidget(
                  id: song.albumId ?? song.songId,
                  type: song.albumId != null
                      ? ArtworkType.ALBUM
                      : ArtworkType.AUDIO,
                  width: 55,
                  height: 55,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isCurrentSong
                          ? FontWeight.bold
                          : FontWeight.w600,
                      overflow: TextOverflow.ellipsis,
                      color: isCurrentSong ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isPlaying)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.equalizer,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          song.artist,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCurrentSong
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (song.duration != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  song.formattedDuration,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            IconButton(
              onPressed: () {
                ref.read(musicLibraryProvider.notifier).toggleFavorite(song.id);
              },
              icon: Icon(
                song.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: song.isFavorite
                    ? Colors.red
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
