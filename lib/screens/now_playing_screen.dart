import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/models/repeat_mode.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/widgets/music_player_controls.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/scrolling_text.dart';

/// Pantalla completa del reproductor de música
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seleccionamos solo el track actual para evitar reconstrucciones innecesarias
    // cuando cambia la posición o el progreso del reproductor.
    final track = ref.watch(audioPlayerProvider.select((s) => s.currentTrack));
    final theme = Theme.of(context);

    if (track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reproductor')),
        body: const Center(child: Text('No hay música reproduciéndose')),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.3),
              theme.colorScheme.surface,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar personalizado
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Reproduciendo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width - 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 32,
                        spreadRadius: 8,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'album_art_${track.id}',
                    child: ArtworkWidget(
                      id: track.albumId ?? track.songId,
                      type: track.albumId != null
                          ? ArtworkType.ALBUM
                          : ArtworkType.AUDIO,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(24),
                      nullIconSize: 120,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Información de la canción
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ScrollingText(
                                text: track.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                duration: const Duration(seconds: 15),
                              ),
                              const SizedBox(height: 8),
                              ScrollingText(
                                text: track.artist,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                duration: const Duration(seconds: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Consumer(
                            builder: (context, ref, _) {
                              // Buscamos la canción actualizada en la biblioteca para obtener el estado real de favorito
                              final isFavorite = ref.watch(
                                musicLibraryProvider.select(
                                  (library) =>
                                      library
                                          .where((s) => s.id == track.id)
                                          .firstOrNull
                                          ?.isFavorite ??
                                      false,
                                ),
                              );
                              return Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 28,
                                color: isFavorite ? Colors.red : null,
                              );
                            },
                          ),
                          onPressed: () {
                            ref
                                .read(musicLibraryProvider.notifier)
                                .toggleFavorite(track.id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Controles de reproducción
              const MusicPlayerControls(),
              const SizedBox(height: 24),
              // Controles adicionales
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final isShuffleEnabled = ref.watch(
                          audioPlayerProvider.select((s) => s.isShuffleEnabled),
                        );

                        return IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            size: 26,
                            color: isShuffleEnabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onPressed: () {
                            ref
                                .read(audioPlayerProvider.notifier)
                                .toggleShuffle();
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.playlist_play, size: 30),
                      onPressed: () => _showPlaylist(context, ref),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final repeatMode = ref.watch(
                          audioPlayerProvider.select((s) => s.repeatMode),
                        );
                        final isActive = repeatMode != RepeatMode.none;

                        return IconButton(
                          icon: Icon(
                            repeatMode.icon,
                            size: 26,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onPressed: () {
                            ref
                                .read(audioPlayerProvider.notifier)
                                .toggleRepeatMode();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaylist(BuildContext context, WidgetRef ref) {
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final playlist = ref.watch(
            audioPlayerProvider.select((s) => s.playlist),
          );
          final currentIndex = ref.watch(
            audioPlayerProvider.select((s) => s.currentIndex),
          );

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lista de reproducción',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${playlist.length} canciones',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final track = playlist[index];
                      final isPlaying = index == currentIndex;

                      return ListTile(
                        leading: ArtworkWidget(
                          id: track.albumId ?? track.songId,
                          type: track.albumId != null
                              ? ArtworkType.ALBUM
                              : ArtworkType.AUDIO,
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(8),
                          nullIcon: isPlaying
                              ? Icons.equalizer
                              : Icons.music_note,
                        ),
                        title: Text(
                          track.title,
                          style: TextStyle(
                            fontWeight: isPlaying
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isPlaying
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          track.formattedDuration,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () {
                          playerNotifier.playTrack(index);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
