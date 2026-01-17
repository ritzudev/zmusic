import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/scrolling_text.dart';

/// Widget de controles de reproducción de música
/// Muestra los controles principales: anterior, play/pause, siguiente
class MusicPlayerControls extends ConsumerWidget {
  final bool showMiniPlayer;

  const MusicPlayerControls({super.key, this.showMiniPlayer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(audioPlayerProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);

    if (playerState.currentTrack == null) {
      return const SizedBox.shrink();
    }

    if (showMiniPlayer) {
      return _buildMiniPlayer(context, playerState, playerNotifier);
    }

    return _buildFullControls(context, playerState, playerNotifier);
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    AudioPlayerState state,
    AudioPlayer notifier,
  ) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de progreso
          LinearProgressIndicator(
            value: state.progress,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            minHeight: 4,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Información de la canción
                  Hero(
                    tag: 'album_art_${state.currentTrack!.id}',
                    child: ArtworkWidget(
                      id:
                          state.currentTrack!.albumId ??
                          state.currentTrack!.songId,
                      type: state.currentTrack!.albumId != null
                          ? ArtworkType.ALBUM
                          : ArtworkType.AUDIO,
                      width: 50,
                      height: 50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScrollingText(
                          text: state.currentTrack!.title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        ScrollingText(
                          text: state.currentTrack!.artist,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                          duration: const Duration(seconds: 12),
                        ),
                      ],
                    ),
                  ),
                  // Controles
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () => notifier.skipToPrevious(),
                  ),
                  IconButton(
                    icon: Icon(
                      state.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 40,
                    ),
                    onPressed: () => notifier.togglePlayPause(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => notifier.skipToNext(),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFullControls(
    BuildContext context,
    AudioPlayerState state,
    AudioPlayer notifier,
  ) {
    return Column(
      children: [
        // Barra de progreso con tiempos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Colors.grey,
                  value: state.progress.clamp(0.0, 1.0),
                  onChanged: (value) {
                    if (state.duration != null) {
                      final position = state.duration! * value;
                      notifier.seek(position);
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(state.position),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatDuration(state.duration ?? Duration.zero),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Controles principales
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 40),
              onPressed: () => notifier.skipToPrevious(),
            ),
            const SizedBox(width: 16),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 48,
                  color: Colors.white,
                ),
                onPressed: () => notifier.togglePlayPause(),
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 40),
              onPressed: () => notifier.skipToNext(),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
