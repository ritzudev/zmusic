import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_filter_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/music_player_controls.dart';
import 'package:zmusic/widgets/scrolling_text.dart';

class HomeWindows extends ConsumerWidget {
  const HomeWindows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filteredSongs = ref.watch(filteredSongsProvider);
    final currentTrack = ref.watch(
      audioPlayerProvider.select((s) => s.currentTrack),
    );
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fondo oscuro tipo Spotify
      body: Row(
        children: [
          // 1. BARRA LATERAL (Sidebar)
          Container(
            width: 240,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo / Título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.music_note,
                        color: Color(0xFF1DB954),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ZMusic',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Menú Principal
                _SidebarItem(
                  icon: Icons.home_filled,
                  label: 'Inicio',
                  isSelected: selectedCategory == 'Todas',
                  onTap: () => ref
                      .read(selectedCategoryProvider.notifier)
                      .update('Todas'),
                ),
                _SidebarItem(
                  icon: Icons.search,
                  label: 'Buscar',
                  onTap: () {}, // Implementar foco en búsqueda
                ),
                _SidebarItem(
                  icon: Icons.library_music,
                  label: 'Tu Biblioteca',
                  onTap: () {},
                ),

                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    'PLAYLISTS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _SidebarItem(
                  icon: Icons.favorite,
                  label: 'Favoritas',
                  isSelected: selectedCategory == 'Favoritas',
                  onTap: () => ref
                      .read(selectedCategoryProvider.notifier)
                      .update('Favoritas'),
                ),

                const Spacer(),

                // Botón Carpeta
                _SidebarItem(
                  icon: Icons.folder_open,
                  label: 'Abrir Carpeta',
                  onTap: () async {
                    await ref
                        .read(musicLibraryProvider.notifier)
                        .pickFolderAndScan();
                  },
                ),
              ],
            ),
          ),

          // 2. CONTENIDO PRINCIPAL (Lista de canciones)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1DB954).withValues(alpha: 0.1),
                    const Color(0xFF121212),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Header de búsqueda y acciones
                  _buildHeader(context, ref, theme),

                  // Lista de temas
                  Expanded(
                    child: _buildSongsTable(context, ref, filteredSongs, theme),
                  ),
                ],
              ),
            ),
          ),

          // 3. PANEL DERECHO (Reproduciendo ahora - Opcional/Visible en Desktop)
          if (currentTrack != null)
            Container(
              width: 320,
              color: const Color(0xFF121212),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Reproduciendo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ArtworkWidget(
                    id: currentTrack.songId,
                    type: ArtworkType.AUDIO,
                    filePath: currentTrack.filePath,
                    width: 270,
                    height: 270,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScrollingText(
                          text: currentTrack.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          currentTrack.artist,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Volumen y otros microcontroles si se desea
                  _buildVolumeControl(ref, theme),
                ],
              ),
            ),
        ],
      ),

      // 4. BARRA DE REPRODUCCIÓN (Bottom Player)
      bottomNavigationBar: currentTrack != null
          ? Container(
              height: 120,
              color: const Color(0xFF181818),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const MusicPlayerControls(showMiniPlayer: true),
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                onChanged: (v) =>
                    ref.read(musicSearchQueryProvider.notifier).update(v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar música, artistas...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Botón Reproducción Aleatoria (Premium Style)
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: () {
                final songs = ref.read(filteredSongsProvider);
                if (songs.isEmpty) return;

                // Lógica idéntica al FloatingActionButton: elegir un índice al azar
                final randomIndex =
                    (songs.length * DateTime.now().millisecond / 1000).floor() %
                    songs.length;

                ref
                    .read(audioPlayerProvider.notifier)
                    .setPlaylistAndPlay(songs, initialIndex: randomIndex);
              },
              child: Row(
                children: [
                  const Icon(Icons.shuffle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ALEATORIO',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.download_for_offline, color: Colors.grey),
            onPressed: () => Navigator.pushNamed(context, '/youtube-search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(width: 16),
          const CircleAvatar(
            backgroundColor: Color(0xFF1DB954),
            child: Text(
              'JU',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTable(
    BuildContext context,
    WidgetRef ref,
    List<MusicTrack> songs,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // Header de tabla
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('#', style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'TÍTULO',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'ÁLBUM',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'DURACIÓN',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, indent: 32, endIndent: 32),
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemBuilder: (context, index) {
              final track = songs[index];
              return _DesktopSongTile(
                track: track,
                index: index,
                playlist: songs,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeControl(WidgetRef ref, ThemeData theme) {
    final volume = ref.watch(audioPlayerProvider.select((s) => s.volume));
    IconData getVolumenIcon() {
      if (volume == 0) return Icons.volume_off;
      if (volume < 0.5) return Icons.volume_mute;
      if (volume < 0.7) return Icons.volume_down;
      return Icons.volume_up;
    }

    return Row(
      children: [
        Icon(getVolumenIcon(), color: Colors.grey, size: 20),
        Expanded(
          child: Slider(
            value: volume,
            activeColor: const Color(0xFF1DB954),
            onChanged: (v) =>
                ref.read(audioPlayerProvider.notifier).setVolume(v),
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF1DB954) : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1DB954) : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DesktopSongTile extends ConsumerWidget {
  final MusicTrack track;
  final int index;
  final List<MusicTrack> playlist;

  const _DesktopSongTile({
    required this.track,
    required this.index,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(
      audioPlayerProvider.select((s) => s.currentTrack?.id == track.id),
    );

    return InkWell(
      onTap: () {
        ref
            .read(audioPlayerProvider.notifier)
            .setPlaylistAndPlay(playlist, initialIndex: index);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isCurrent ? const Color(0xFF1DB954) : Colors.grey,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  ArtworkWidget(
                    id: track.songId,
                    type: ArtworkType.AUDIO,
                    filePath: track.filePath,
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: TextStyle(
                            color: isCurrent
                                ? const Color(0xFF1DB954)
                                : Colors.white,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artist,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                track.album ?? 'Single',
                style: const TextStyle(color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 80,
              child: Row(
                children: [
                  Text(
                    track.formattedDuration,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ref
                          .read(musicLibraryProvider.notifier)
                          .toggleFavorite(track.id);
                    },
                    icon: Icon(
                      track.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: track.isFavorite ? Colors.red : Colors.grey,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
