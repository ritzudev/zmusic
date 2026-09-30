import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart' hide PlaylistModel;
import 'package:zmusic/models/playlist_model.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_filter_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/providers/playlist_provider.dart';
import 'package:zmusic/services/typing_state.dart';
import 'package:zmusic/widgets/add_to_playlist_dialog.dart';
import 'package:zmusic/widgets/ambient_glow_background.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/audio_visualizer_widget.dart';
import 'package:zmusic/widgets/music_player_controls.dart';
import 'package:zmusic/widgets/scrolling_text.dart';
import 'package:zmusic/widgets/windows_title_bar.dart';


class HomeWindows extends ConsumerStatefulWidget {
  const HomeWindows({super.key});

  @override
  ConsumerState<HomeWindows> createState() => _HomeWindowsState();
}

class _HomeWindowsState extends ConsumerState<HomeWindows> {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      TypingState.isTyping = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _CreatePlaylistDialog(),
    );
  }

  void _showRenamePlaylistDialog(PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (ctx) => _RenamePlaylistDialog(playlist: playlist),
    );
  }



  void _confirmDeletePlaylist(PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(
              'Eliminar Lista',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la lista "${playlist.name}"? Las canciones no se borrarán de tu biblioteca.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await ref
                  .read(playlistProvider.notifier)
                  .deletePlaylist(playlist.id);
              final currentCat = ref.read(selectedCategoryProvider);
              if (currentCat == 'playlist:${playlist.id}') {
                ref.read(selectedCategoryProvider.notifier).update('Todas');
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredSongs = ref.watch(filteredSongsProvider);
    final currentTrack = ref.watch(
      audioPlayerProvider.select((s) => s.currentTrack),
    );
    final isPlaying = ref.watch(
      audioPlayerProvider.select((s) => s.isPlaying),
    );
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final primaryColor = theme.colorScheme.primary;

    // Colores de superficie con micro-tinte para mayor vitalidad cromática
    final cardBgColor = Color.alphaBlend(
      primaryColor.withValues(alpha: 0.05),
      const Color(0xFF10131B),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientGlowBackground(
        accentColor: primaryColor,
        baseColor: const Color(0xFF080A10),
        intensity: isPlaying ? 0.35 : 0.22,
        child: Column(
          children: [
            // 1. BARRA DE TÍTULO MODERNA WINDOWS 11
            WindowsTitleBar(
              height: 42,
              backgroundColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ZMusic',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. DISPOSICIÓN BENTO GRID DE PANELES FLOTANTES
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. SIDEBAR FLOTANTE
                    Container(
                      width: 240,
                      decoration: BoxDecoration(
                        color: cardBgColor.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.16),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'DESCUBRIR',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white38,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  _SidebarItem(
                                    icon: Icons.home_rounded,
                                    label: 'Inicio',
                                    isSelected: selectedCategory == 'Todas',
                                    primaryColor: primaryColor,
                                    onTap: () => ref
                                        .read(selectedCategoryProvider.notifier)
                                        .update('Todas'),
                                  ),
                                  _SidebarItem(
                                    icon: Icons.search_rounded,
                                    label: 'Buscar',
                                    isSelected: false,
                                    primaryColor: primaryColor,
                                    onTap: () {
                                      _searchFocusNode.requestFocus();
                                    },
                                  ),

                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'FUENTES ONLINE',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white38,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  _SidebarItem(
                                    icon: Icons.cloud_download_rounded,
                                    label: 'YouTube Invidious',
                                    iconColor: const Color(0xFF00E5FF),
                                    primaryColor: primaryColor,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/invidious-search',
                                    ),
                                  ),
                                  _SidebarItem(
                                    icon: Icons.play_circle_fill_rounded,
                                    label: 'YouTube Music',
                                    iconColor: const Color(0xFFFF2A55),
                                    primaryColor: primaryColor,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/youtube-search',
                                    ),
                                  ),

                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'COLECCIÓN',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white38,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  _SidebarItem(
                                    icon: Icons.download_done_rounded,
                                    label: 'Descargas',
                                    iconColor: const Color(0xFF00E676),
                                    isSelected: selectedCategory == 'Descargas',
                                    primaryColor: primaryColor,
                                    onTap: () => ref
                                        .read(selectedCategoryProvider.notifier)
                                        .update('Descargas'),
                                  ),
                                  _SidebarItem(
                                    icon: Icons.favorite_rounded,
                                    label: 'Favoritas',
                                    iconColor: Colors.pinkAccent,
                                    isSelected: selectedCategory == 'Favoritas',
                                    primaryColor: primaryColor,
                                    onTap: () => ref
                                        .read(selectedCategoryProvider.notifier)
                                        .update('Favoritas'),
                                  ),

                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'LISTAS',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: Colors.white38,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                            fontSize: 10,
                                          ),
                                        ),
                                        IconButton(
                                          iconSize: 16,
                                          tooltip: 'Crear nueva lista',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          icon: Icon(
                                            Icons.add_rounded,
                                            color: primaryColor,
                                          ),
                                          onPressed: _showCreatePlaylistDialog,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final playlists =
                                          ref.watch(playlistProvider);
                                      if (playlists.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 6,
                                          ),
                                          child: Text(
                                            'Sin listas creadas',
                                            style: TextStyle(
                                              color: Colors.white24,
                                              fontSize: 11.5,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        );
                                      }
                                      return Column(
                                        children: playlists.map((pl) {
                                          final isPlSelected =
                                              selectedCategory ==
                                                  'playlist:${pl.id}';
                                          return _SidebarPlaylistItem(
                                            playlist: pl,
                                            isSelected: isPlSelected,
                                            primaryColor: primaryColor,
                                            onTap: () => ref
                                                .read(
                                                  selectedCategoryProvider
                                                      .notifier,
                                                )
                                                .update('playlist:${pl.id}'),
                                            onRename: () =>
                                                _showRenamePlaylistDialog(pl),
                                            onDelete: () =>
                                                _confirmDeletePlaylist(pl),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Divider(
                            color: Colors.white10,
                            indent: 16,
                            endIndent: 16,
                          ),
                          const SizedBox(height: 4),

                          _SidebarItem(
                            icon: Icons.folder_open_rounded,
                            label: 'Abrir Carpeta',
                            primaryColor: primaryColor,
                            onTap: () async {
                              await ref
                                  .read(musicLibraryProvider.notifier)
                                  .pickFolderAndScan();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    // B. PANEL CENTRAL (Lista de canciones y biblioteca)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBgColor.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.16),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Cabecera superior con botones vibrantes
                            _buildHeader(context, ref, theme, primaryColor),
                            // Filtros de categoría rápidos
                            _buildFilterChips(ref, selectedCategory, primaryColor),
                            // Lista de temas
                            Expanded(
                              child: _buildSongsTable(
                                context,
                                ref,
                                filteredSongs,
                                theme,
                                primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // C. PANEL DERECHO (Reproduciendo ahora - Bento Card)
                    if (currentTrack != null) ...[
                      const SizedBox(width: 14),
                      Container(
                        width: 310,
                        decoration: BoxDecoration(
                          color: cardBgColor.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.20),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'REPRODUCIENDO',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.3,
                                    fontSize: 10.5,
                                  ),
                                ),
                                if (isPlaying)
                                  AudioVisualizerWidget(
                                    isPlaying: true,
                                    barCount: 4,
                                    height: 14,
                                    barWidth: 2.5,
                                    color: primaryColor,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Portada con sombra reactiva viva
                            Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(
                                        alpha: isPlaying ? 0.45 : 0.2,
                                      ),
                                      blurRadius: 32,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ArtworkWidget(
                                  id: currentTrack.songId,
                                  type: ArtworkType.AUDIO,
                                  filePath: currentTrack.filePath,
                                  width: 260,
                                  height: 260,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Título y artista
                            ScrollingText(
                              text: currentTrack.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ScrollingText(
                              text: currentTrack.artist,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              duration: const Duration(seconds: 12),
                            ),

                            const SizedBox(height: 16),
                            // Badge de álbum
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.album_rounded,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      currentTrack.album ?? 'Sencillo',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Favorito + duración
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.08),
                                  ),
                                  icon: Icon(
                                    currentTrack.isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: currentTrack.isFavorite
                                        ? Colors.redAccent
                                        : Colors.white70,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(musicLibraryProvider.notifier)
                                        .toggleFavorite(currentTrack.id);
                                  },
                                ),
                                const Spacer(),
                                Text(
                                  currentTrack.formattedDuration,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 3. BARRA DE REPRODUCCIÓN INFERIOR
      bottomNavigationBar: currentTrack != null
          ? const MusicPlayerControls(showMiniPlayer: true)
          : null,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Color primary,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          // Campo de búsqueda amplio y prioritario
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Consumer(
                builder: (context, ref, child) {
                  final searchQuery = ref.watch(musicSearchQueryProvider);
                  return TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (v) =>
                        ref.read(musicSearchQueryProvider.notifier).update(v),
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Buscar canciones, artistas, álbumes...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: primary,
                        size: 20,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Colors.white60,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(musicSearchQueryProvider.notifier)
                                    .clear();
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Botón Reproducción Aleatoria Vibrante
          _PillActionButton(
            label: 'ALEATORIO',
            icon: Icons.shuffle_rounded,
            gradient: LinearGradient(
              colors: [
                primary,
                Color.alphaBlend(Colors.black26, primary),
              ],
            ),
            glowColor: primary,
            onPressed: () {
              final songs = ref.read(filteredSongsProvider);
              if (songs.isEmpty) return;
              ref.read(audioPlayerProvider.notifier).playAllShuffled(songs);
            },
          ),
          const SizedBox(width: 10),

          // Botón Invidious / YouTube (Icono con color Cian Neón)
          _HeaderGlowIconButton(
            icon: Icons.cloud_download_rounded,
            tooltip: 'YouTube (Invidious)',
            glowColor: const Color(0xFF00E5FF),
            iconColor: const Color(0xFF00E5FF),
            onPressed: () => Navigator.pushNamed(context, '/invidious-search'),
          ),
          const SizedBox(width: 8),

          // Botón YouTube Music (Icono con color Rojo Neón)
          _HeaderGlowIconButton(
            icon: Icons.play_circle_fill_rounded,
            tooltip: 'YouTube Music',
            glowColor: const Color(0xFFFF1744),
            iconColor: const Color(0xFFFF2A55),
            onPressed: () => Navigator.pushNamed(context, '/youtube-search'),
          ),
          const SizedBox(width: 8),

          // Botón Configuración
          _HeaderGlowIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'Configuración',
            glowColor: Colors.white24,
            iconColor: Colors.white70,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(
    WidgetRef ref,
    String selectedCategory,
    Color primary,
  ) {
    final playlists = ref.watch(playlistProvider);
    final isPlaylist = selectedCategory.startsWith('playlist:');
    final activePlaylistId =
        isPlaylist ? selectedCategory.replaceFirst('playlist:', '') : '';
    final activePlaylist = isPlaylist
        ? playlists.firstWhere(
            (p) => p.id == activePlaylistId,
            orElse: () =>
                PlaylistModel(id: '', name: '', songIds: [], createdAt: 0),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          _CategoryChip(
            label: 'Todas las canciones',
            isSelected: selectedCategory == 'Todas',
            primaryColor: primary,
            onTap: () => ref
                .read(selectedCategoryProvider.notifier)
                .update('Todas'),
          ),
          const SizedBox(width: 8),
          _CategoryChip(
            label: 'Descargas',
            icon: Icons.download_done_rounded,
            iconColor: const Color(0xFF00E676),
            isSelected: selectedCategory == 'Descargas',
            primaryColor: primary,
            onTap: () => ref
                .read(selectedCategoryProvider.notifier)
                .update('Descargas'),
          ),
          const SizedBox(width: 8),
          _CategoryChip(
            label: 'Favoritas',
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            isSelected: selectedCategory == 'Favoritas',
            primaryColor: primary,
            onTap: () => ref
                .read(selectedCategoryProvider.notifier)
                .update('Favoritas'),
          ),
          if (activePlaylist != null && activePlaylist.id.isNotEmpty) ...[
            const SizedBox(width: 8),
            _CategoryChip(
              label: 'Lista: ${activePlaylist.name}',
              icon: Icons.queue_music_rounded,
              iconColor: const Color(0xFFFFB300),
              isSelected: true,
              primaryColor: primary,
              onTap: () {},
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSongsTable(
    BuildContext context,
    WidgetRef ref,
    List<MusicTrack> songs,
    ThemeData theme,
    Color primary,
  ) {
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 48,
              color: primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'No se encontraron canciones',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 44,
                child: Text(
                  '#',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Expanded(
                flex: 4,
                child: Text(
                  'TÍTULO',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'ÁLBUM',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'DURACIÓN',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(
          color: Colors.white10,
          indent: 20,
          endIndent: 20,
          height: 1,
        ),
        const SizedBox(height: 4),

        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemBuilder: (context, index) {
              final track = songs[index];
              return _DesktopSongTile(
                track: track,
                index: index,
                playlist: songs,
                primaryColor: primary,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SidebarPlaylistItem extends StatefulWidget {
  final PlaylistModel playlist;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SidebarPlaylistItem({
    required this.playlist,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_SidebarPlaylistItem> createState() => _SidebarPlaylistItemState();
}

class _SidebarPlaylistItemState extends State<_SidebarPlaylistItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.primaryColor.withValues(alpha: 0.20)
                : _isHovered
                    ? widget.primaryColor.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? widget.primaryColor.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.queue_music_rounded,
                color: widget.isSelected
                    ? widget.primaryColor
                    : const Color(0xFFFFB300),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.name,
                      style: TextStyle(
                        color: widget.isSelected
                            ? Colors.white
                            : _isHovered
                                ? Colors.white
                                : Colors.white70,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.playlist.songIds.length} canciones',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isHovered || widget.isSelected)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 16,
                    color: Colors.white60,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Opciones',
                  color: const Color(0xFF1E222D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  onSelected: (val) {
                    if (val == 'rename') widget.onRename();
                    if (val == 'delete') widget.onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'rename',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 16, color: Colors.white70),
                          SizedBox(width: 8),
                          Text('Renombrar',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded,
                              size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Eliminar',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color glowColor;
  final VoidCallback onPressed;

  const _PillActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.glowColor,
    required this.onPressed,
  });

  @override
  State<_PillActionButton> createState() => _PillActionButtonState();
}

class _PillActionButtonState extends State<_PillActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: _isHovered ? 0.55 : 0.35,
                ),
                blurRadius: _isHovered ? 18 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    this.icon,
    this.iconColor,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? primaryColor : iconColor ?? Colors.white70,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderGlowIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color glowColor;
  final Color iconColor;
  final VoidCallback onPressed;

  const _HeaderGlowIconButton({
    required this.icon,
    required this.tooltip,
    required this.glowColor,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  State<_HeaderGlowIconButton> createState() => _HeaderGlowIconButtonState();
}

class _HeaderGlowIconButtonState extends State<_HeaderGlowIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.glowColor.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? widget.glowColor.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: _isHovered ? Colors.white : widget.iconColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color? iconColor;
  final Color primaryColor;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.iconColor,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.primaryColor.withValues(alpha: 0.20)
                : _isHovered
                    ? widget.primaryColor.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? widget.primaryColor.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected
                    ? widget.primaryColor
                    : widget.iconColor ??
                        (_isHovered ? Colors.white : Colors.white60),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : _isHovered
                            ? Colors.white
                            : Colors.white70,
                    fontWeight: widget.isSelected
                        ? FontWeight.bold
                        : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (widget.isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryColor.withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSongTile extends ConsumerStatefulWidget {
  final MusicTrack track;
  final int index;
  final List<MusicTrack> playlist;
  final Color primaryColor;

  const _DesktopSongTile({
    required this.track,
    required this.index,
    required this.playlist,
    required this.primaryColor,
  });

  @override
  ConsumerState<_DesktopSongTile> createState() => _DesktopSongTileState();
}

class _DesktopSongTileState extends ConsumerState<_DesktopSongTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currentTrackId = ref.watch(
      audioPlayerProvider.select((s) => s.currentTrack?.id),
    );
    final isCurrent = currentTrackId == widget.track.id;
    final isPlaying = ref.watch(
      audioPlayerProvider.select((s) => s.isPlaying),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref
              .read(audioPlayerProvider.notifier)
              .setPlaylistAndPlay(widget.playlist, initialIndex: widget.index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrent
                ? widget.primaryColor.withValues(alpha: 0.16)
                : _isHovered
                    ? widget.primaryColor.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? widget.primaryColor.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: isCurrent && isPlaying
                    ? AudioVisualizerWidget(
                        isPlaying: true,
                        barCount: 3,
                        height: 14,
                        barWidth: 2,
                        color: widget.primaryColor,
                      )
                    : _isHovered
                        ? Icon(
                            isCurrent && isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: isCurrent ? widget.primaryColor : Colors.white,
                            size: 20,
                          )
                        : Text(
                            '${widget.index + 1}',
                            style: TextStyle(
                              color: isCurrent
                                  ? widget.primaryColor
                                  : Colors.white38,
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
              ),

              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    ArtworkWidget(
                      id: widget.track.songId,
                      type: ArtworkType.AUDIO,
                      filePath: widget.track.filePath,
                      width: 42,
                      height: 42,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.track.title,
                            style: TextStyle(
                              color: isCurrent
                                  ? widget.primaryColor
                                  : Colors.white,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.track.artist,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 3,
                child: Text(
                  widget.track.album ?? 'Sencillo',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      widget.track.formattedDuration,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      iconSize: 18,
                      tooltip: 'Añadir a lista...',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: () {
                        AddToPlaylistDialog.show(context, widget.track);
                      },
                      icon: Icon(
                        Icons.playlist_add_rounded,
                        color: _isHovered ? Colors.white70 : Colors.transparent,
                      ),
                    ),
                    IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: () {
                        ref
                            .read(musicLibraryProvider.notifier)
                            .toggleFavorite(widget.track.id);
                      },
                      icon: Icon(
                        widget.track.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: widget.track.isFavorite
                            ? Colors.redAccent
                            : _isHovered
                                ? Colors.white54
                                : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePlaylistDialog extends ConsumerStatefulWidget {
  const _CreatePlaylistDialog();

  @override
  ConsumerState<_CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState
    extends ConsumerState<_CreatePlaylistDialog> {
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

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      final pl =
          await ref.read(playlistProvider.notifier).createPlaylist(name);
      ref.read(selectedCategoryProvider.notifier).update('playlist:${pl.id}');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161922),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      title: const Row(
        children: [
          Icon(Icons.playlist_add_rounded, color: Color(0xFFFFB300)),
          SizedBox(width: 10),
          Text(
            'Nueva Lista',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Nombre de la lista...',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _RenamePlaylistDialog extends ConsumerStatefulWidget {
  final PlaylistModel playlist;
  const _RenamePlaylistDialog({required this.playlist});

  @override
  ConsumerState<_RenamePlaylistDialog> createState() =>
      _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState
    extends ConsumerState<_RenamePlaylistDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.playlist.name);
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

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      await ref
          .read(playlistProvider.notifier)
          .renamePlaylist(widget.playlist.id, name);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161922),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      title: const Row(
        children: [
          Icon(Icons.edit_rounded, color: Color(0xFFFFB300)),
          SizedBox(width: 10),
          Text(
            'Renombrar Lista',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Nuevo nombre...',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Cancelar', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

