import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/models/repeat_mode.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/widgets/music_player_controls.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/scrolling_text.dart';

/// Versión optimizada para Windows de la pantalla de reproducción
class NowPlayingWindows extends ConsumerWidget {
  const NowPlayingWindows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(audioPlayerProvider.select((s) => s.currentTrack));
    final theme = Theme.of(context);

    if (track == null) return const SizedBox.shrink();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Row(
          children: [
            // PARTE IZQUIERDA: Arte, Info y Volumen
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón volver arriba a la izquierda
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                    // Arte del álbum grande
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: ArtworkWidget(
                          id: track.songId,
                          type: ArtworkType.AUDIO,
                          filePath: track.filePath,
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: BorderRadius.circular(32),
                          nullIconSize: 150,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Título y Artista
                    ScrollingText(
                      text: track.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.artist,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Control de Volumen
                    _buildVolumeSlider(ref, theme),
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // LINEA DIVISORIA SUTIL
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            ),

            // PARTE DERECHA: Playlist y Controles Principales
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  // Título de la lista
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Siguiente en la lista',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildActionButtons(ref, theme),
                      ],
                    ),
                  ),

                  // Lista de reproducción siempre visible
                  Expanded(child: _buildPlaylistView(context, ref, theme)),

                  // Controles de reproducción fijos abajo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 48,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: const MusicPlayerControls(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeSlider(WidgetRef ref, ThemeData theme) {
    final volume = ref.watch(audioPlayerProvider.select((s) => s.volume));
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Row(
        children: [
          Icon(Icons.volume_mute, size: 20, color: theme.colorScheme.primary),
          Expanded(
            child: Slider(
              value: volume,
              onChanged: (v) =>
                  ref.read(audioPlayerProvider.notifier).setVolume(v),
              activeColor: theme.colorScheme.primary,
            ),
          ),
          Icon(Icons.volume_up, size: 20, color: theme.colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildActionButtons(WidgetRef ref, ThemeData theme) {
    final isShuffle = ref.watch(
      audioPlayerProvider.select((s) => s.isShuffleEnabled),
    );
    final repeatMode = ref.watch(
      audioPlayerProvider.select((s) => s.repeatMode),
    );

    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: isShuffle ? theme.colorScheme.primary : null,
          ),
          onPressed: () =>
              ref.read(audioPlayerProvider.notifier).toggleShuffle(),
          tooltip: 'Aleatorio',
        ),
        IconButton(
          icon: Icon(
            repeatMode.icon,
            color: repeatMode != RepeatMode.none
                ? theme.colorScheme.primary
                : null,
          ),
          onPressed: () =>
              ref.read(audioPlayerProvider.notifier).toggleRepeatMode(),
          tooltip: 'Repetir',
        ),
      ],
    );
  }

  Widget _buildPlaylistView(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final playlist = ref.watch(audioPlayerProvider.select((s) => s.playlist));
    final currentIndex = ref.watch(
      audioPlayerProvider.select((s) => s.currentIndex),
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: playlist.length,
      itemBuilder: (context, index) {
        final track = playlist[index];
        final isPlaying = index == currentIndex;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: ArtworkWidget(
              id: track.songId,
              type: ArtworkType.AUDIO,
              filePath: track.filePath,
              width: 50,
              height: 50,
              borderRadius: BorderRadius.circular(8),
              nullIcon: isPlaying ? Icons.equalizer : Icons.music_note,
            ),
            title: Text(
              track.title,
              style: TextStyle(
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                color: isPlaying ? theme.colorScheme.primary : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(track.artist, maxLines: 1),
            trailing: Text(track.formattedDuration),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            selected: isPlaying,
            selectedTileColor: theme.colorScheme.primary.withValues(
              alpha: 0.05,
            ),
            onTap: () =>
                ref.read(audioPlayerProvider.notifier).playTrack(index),
          ),
        );
      },
    );
  }
}
