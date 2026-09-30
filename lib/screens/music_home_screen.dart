import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart' hide PlaylistModel;
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/models/playlist_model.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_filter_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/providers/playlist_provider.dart';
import 'package:zmusic/screens/now_playing_screen.dart';
import 'package:zmusic/screens/playlist_detail_screen.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/add_to_playlist_dialog.dart';
import 'package:zmusic/widgets/music_player_controls.dart';
import 'package:zmusic/widgets/download_status_bar.dart';
import 'package:zmusic/providers/youtube_provider.dart';
import 'package:zmusic/screens/home/home_windows.dart';

import 'package:zmusic/services/typing_state.dart';
import 'package:zmusic/services/update_service.dart';

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
      UpdateService().checkForUpdates(context);
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

    // Reproducir toda la lista en modo aleatorio (Shuffle real)
    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    await playerNotifier.playAllShuffled(filteredSongs);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si estamos en Windows y hay más de 900px de ancho, usar la vista de escritorio avanzada
        if (Platform.isWindows && constraints.maxWidth > 900) {
          return const HomeWindows();
        }

        // De lo contrario, usar la vista móvil original (contenida en _buildMobileHome)
        return _buildMobileHome(context);
      },
    );
  }

  Widget _buildMobileHome(BuildContext context) {
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Barra de Búsqueda y Acciones Rápidas
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: theme.textTheme.bodyMedium,
                            onChanged: (value) {
                              ref
                                  .read(musicSearchQueryProvider.notifier)
                                  .update(value);
                            },
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: "Buscar canciones o artistas...",
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                      ),
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
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Menú de descargas (YouTube / Invidious)
                      PopupMenuButton<String>(
                        tooltip: 'Descargas de música',
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        icon: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.cloud_download_rounded,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        onSelected: (value) {
                          HapticFeedback.lightImpact();
                          if (value == 'youtube') {
                            Navigator.pushNamed(context, '/youtube-search');
                          } else if (value == 'invidious') {
                            Navigator.pushNamed(context, '/invidious-search');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'youtube',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded, size: 20),
                                SizedBox(width: 12),
                                Text('YouTube'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'invidious',
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 20),
                                SizedBox(width: 12),
                                Text('Invidious (Rápido)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      // Botón de Ajustes
                      IconButton(
                        tooltip: 'Ajustes',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pushNamed(context, '/settings');
                        },
                        icon: Icon(
                          Icons.settings_outlined,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 2. Cabecera "Mi Música" con botón Aleatorio y Filtros
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Mi Música",
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "${filteredSongsList.length} canciones",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Botón Shuffle / Aleatorio destacado y de alto contraste
                      FilledButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _playRandomSong();
                              },
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: 20,
                          color: theme.colorScheme.onPrimary,
                        ),
                        label: Text(
                          "Aleatorio",
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          elevation: 3,
                          shadowColor: theme.colorScheme.primary.withValues(
                            alpha: 0.45,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Chips de Categoría
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: "Todas",
                          isSelected: selectedCategory == "Todas",
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(selectedCategoryProvider.notifier)
                                .update("Todas");
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: "Listas",
                          icon: Icons.queue_music_rounded,
                          isSelected: selectedCategory == "Listas",
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(selectedCategoryProvider.notifier)
                                .update("Listas");
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: "Descargas",
                          icon: Icons.download_done_rounded,
                          isSelected: selectedCategory == "Descargas",
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(selectedCategoryProvider.notifier)
                                .update("Descargas");
                          },
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: "Favoritas",
                          icon: Icons.favorite_rounded,
                          isSelected: selectedCategory == "Favoritas",
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(selectedCategoryProvider.notifier)
                                .update("Favoritas");
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 3. Lista de Canciones o Listas Personalizadas
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _loadingMessage,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Esto puede tomar unos segundos...",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : selectedCategory == "Listas"
                      ? const _PlaylistsView()
                      : RefreshIndicator(
                          onRefresh: () async {
                            HapticFeedback.mediumImpact();
                            await _scanMusic();
                          },
                          color: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.surface,
                          child: filteredSongsList.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height * 0.45,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                selectedCategory == 'Favoritas'
                                                    ? Icons.favorite_border_rounded
                                                    : (selectedCategory ==
                                                            'Descargas'
                                                        ? Icons
                                                            .cloud_download_outlined
                                                        : Icons.search_off_rounded),
                                                size: 72,
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.3),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                selectedCategory == 'Favoritas'
                                                    ? "No tienes canciones favoritas"
                                                    : (selectedCategory ==
                                                            'Descargas'
                                                        ? "Sin descargas de hoy"
                                                        : (searchQuery.isEmpty
                                                              ? "No se encontró música"
                                                              : "Sin resultados para '$searchQuery'")),
                                                style: theme.textTheme.titleMedium
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(alpha: 0.7),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                selectedCategory == 'Favoritas'
                                                    ? "Toca el corazón en tus canciones preferidas"
                                                    : (selectedCategory ==
                                                            'Descargas'
                                                        ? "Descarga canciones desde YouTube o Invidious para escucharlas offline"
                                                        : (searchQuery.isEmpty
                                                              ? "Desliza hacia abajo para escanear"
                                                              : "Intenta con otro término de búsqueda")),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(alpha: 0.5),
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                              if (selectedCategory == 'Descargas') ...[
                                                const SizedBox(height: 18),
                                                FilledButton.icon(
                                                  onPressed: () {
                                                    HapticFeedback.lightImpact();
                                                    Navigator.pushNamed(
                                                      context,
                                                      '/invidious-search',
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.bolt_rounded,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    "Descargar con Invidious",
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor:
                                                        theme.colorScheme.primary,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Consumer(
                                  builder: (context, ref, child) {
                                    final hasPlayer =
                                        ref.watch(audioPlayerProvider).currentTrack !=
                                        null;
                                    final hasDownload =
                                        ref.watch(youTubeDownloadProvider) != null;
                                    final recentList =
                                        ref.watch(recentDownloadsProvider);
                                    final showRecentSection =
                                        selectedCategory == 'Todas' &&
                                        searchQuery.isEmpty &&
                                        recentList.isNotEmpty;

                                    double bottomPadding = 16;
                                    if (hasPlayer) bottomPadding += 80;
                                    if (hasDownload) bottomPadding += 70;

                                    return CustomScrollView(
                                      physics: const AlwaysScrollableScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      slivers: [
                                        if (showRecentSection)
                                          SliverToBoxAdapter(
                                            child: _RecentDownloadsSection(
                                              songs: recentList,
                                            ),
                                          ),
                                        SliverPadding(
                                          padding: EdgeInsets.only(
                                            left: 16.0,
                                            right: 16.0,
                                            bottom: bottomPadding,
                                          ),
                                          sliver: SliverList(
                                            delegate: SliverChildBuilderDelegate(
                                              (context, index) {
                                                return _MusicCard(
                                                  song: filteredSongsList[index],
                                                  index: index,
                                                  filteredPlaylist:
                                                      filteredSongsList,
                                                );
                                              },
                                              childCount: filteredSongsList.length,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
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
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const NowPlayingScreen(),
                        transitionDuration: const Duration(milliseconds: 350),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 350,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              const curve = Curves.easeOutCubic;
                              final curvedAnimation = CurvedAnimation(
                                parent: animation,
                                curve: curve,
                                reverseCurve: curve,
                              );
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 1),
                                  end: Offset.zero,
                                ).animate(curvedAnimation),
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
            const DownloadStatusBar(),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
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
        // Cerrar el teclado si está abierto
        FocusScope.of(context).unfocus();

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
                  id: song.songId,
                  type: ArtworkType.AUDIO,
                  filePath: song.filePath,
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
                          child: AnimatedEqualizer(
                            color: theme.colorScheme.primary,
                            size: 16,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          song.artist,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isCurrentSong
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
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
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  song.formattedDuration,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Añadir a lista',
              onPressed: () {
                AddToPlaylistDialog.show(context, song);
              },
              icon: Icon(
                Icons.playlist_add_rounded,
                size: 22,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
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
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedEqualizer extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedEqualizer({super.key, required this.color, this.size = 16});

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Creamos variaciones de altura para cada barra
              double value = (index == 1)
                  ? _controller.value
                  : (index == 0)
                  ? (1.0 - _controller.value).clamp(0.3, 1.0)
                  : (_controller.value + 0.3).clamp(0.4, 0.9);

              return Container(
                width: widget.size / 5,
                height: widget.size * value,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _RecentDownloadsSection extends ConsumerWidget {
  final List<MusicTrack> songs;

  const _RecentDownloadsSection({required this.songs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displaySongs = songs.take(5).toList();

    if (displaySongs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Descargas de Hoy",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${displaySongs.length}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedCategoryProvider.notifier).update("Descargas");
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Ver todas",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 175,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displaySongs.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _RecentDownloadCard(
                  song: displaySongs[index],
                  index: index,
                  playlist: songs,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  "Todas las canciones",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDownloadCard extends ConsumerWidget {
  final MusicTrack song;
  final int index;
  final List<MusicTrack> playlist;

  const _RecentDownloadCard({
    required this.song,
    required this.index,
    required this.playlist,
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
        FocusScope.of(context).unfocus();
        final playerNotifier = ref.read(audioPlayerProvider.notifier);

        if (isCurrentSong) {
          await playerNotifier.togglePlayPause();
        } else {
          await playerNotifier.setPlaylistAndPlay(
            playlist,
            initialIndex: index,
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentSong
                ? theme.colorScheme.primary.withValues(alpha: 0.6)
                : theme.colorScheme.outline.withValues(alpha: 0.12),
            width: isCurrentSong ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ArtworkWidget(
                  id: song.songId,
                  type: ArtworkType.AUDIO,
                  filePath: song.filePath,
                  width: 104,
                  height: 100,
                  borderRadius: BorderRadius.circular(10),
                ),
                if (isCurrentSong)
                  Container(
                    width: 104,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: isPlaying
                          ? const AnimatedEqualizer(
                              color: Colors.white,
                              size: 20,
                            )
                          : const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: isCurrentSong ? theme.colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistsView extends ConsumerWidget {
  const _PlaylistsView();

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _MobileCreatePlaylistDialog(),
    );
  }



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playlists = ref.watch(playlistProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${playlists.length} listas personalizadas",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Nueva lista"),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: playlists.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 72,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No tienes listas personalizadas",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Organiza tus canciones por género, estado de ánimo o artistas favoritos",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => _showCreateDialog(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text("Crear mi primera lista"),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  physics: const BouncingScrollPhysics(),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return _PlaylistTile(playlist: playlist);
                  },
                ),
        ),
      ],
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final PlaylistModel playlist;

  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final songs = ref.watch(playlistSongsProvider(playlist.id));

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistDetailScreen(playlistId: playlist.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            // Artwork / Icono de Playlist
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: songs.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ArtworkWidget(
                        id: songs.first.songId,
                        type: ArtworkType.AUDIO,
                        filePath: songs.first.filePath,
                        width: 58,
                        height: 58,
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${playlist.songIds.length} canciones",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (songs.isNotEmpty)
              IconButton.filledTonal(
                tooltip: 'Reproducir lista',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(audioPlayerProvider.notifier).setPlaylistAndPlay(
                        songs,
                        initialIndex: 0,
                      );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCreatePlaylistDialog extends ConsumerStatefulWidget {
  const _MobileCreatePlaylistDialog();

  @override
  ConsumerState<_MobileCreatePlaylistDialog> createState() =>
      _MobileCreatePlaylistDialogState();
}

class _MobileCreatePlaylistDialogState
    extends ConsumerState<_MobileCreatePlaylistDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      TypingState.isTyping = _focusNode.hasFocus;
    });
    TypingState.isTyping = true;
  }

  @override
  void dispose() {
    TypingState.isTyping = false;
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      ref.read(playlistProvider.notifier).createPlaylist(name);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Lista Personalizada'),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Ej. Favoritas del verano, Rock...',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}


