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
    final theme = Theme.of(context);
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Información de la canción
                      Hero(
                        tag: 'album_art_${state.currentTrack!.id}',
                        child: ArtworkWidget(
                          id: state.currentTrack!.songId,
                          type: ArtworkType.AUDIO,
                          filePath: state.currentTrack!.filePath,
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
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: IconButton(
                          icon: Icon(
                            state.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () => notifier.togglePlayPause(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: () => notifier.skipToNext(),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: theme.brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(state.position),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        _formatDuration(state.duration ?? Duration.zero),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                color: Theme.of(context).colorScheme.primary,
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
