import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/models/repeat_mode.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/scrolling_text.dart';
import 'package:zmusic/widgets/audio_visualizer_widget.dart';
import 'package:zmusic/screens/now_playing_screen.dart';

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
      if (!kIsWeb && io.Platform.isWindows) {
        return _buildWindowsMiniPlayer(context, playerState, playerNotifier);
      }
      // En Web también podemos usar el diseño de Windows si la pantalla es ancha
      if (kIsWeb && MediaQuery.of(context).size.width > 900) {
        return _buildWindowsMiniPlayer(context, playerState, playerNotifier);
      }
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
    final track = state.currentTrack!;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            // Deslizar a la izquierda -> Siguiente
            HapticFeedback.mediumImpact();
            notifier.skipToNext();
          } else if (details.primaryVelocity! > 200) {
            // Deslizar a la derecha -> Anterior
            HapticFeedback.mediumImpact();
            notifier.skipToPrevious();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        height: 66,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Barra de progreso delgada arriba
            SizedBox(
              height: 2.5,
              child: LinearProgressIndicator(
                value: state.progress.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            // Contenido principal compacto
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    // Arte de la carátula redondeado
                    Hero(
                      tag: 'album_art_${track.id}',
                      child: ArtworkWidget(
                        id: track.songId,
                        type: ArtworkType.AUDIO,
                        filePath: track.filePath,
                        width: 44,
                        height: 44,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Título y artista
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ScrollingText(
                            text: track.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                            duration: const Duration(seconds: 12),
                          ),
                          const SizedBox(height: 2),
                          ScrollingText(
                            text: track.artist,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                              fontSize: 11.5,
                            ),
                            duration: const Duration(seconds: 10),
                          ),
                        ],
                      ),
                    ),
                    // Botón Anterior
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 24),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.skipToPrevious();
                      },
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    // Botón Play / Pause circular
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          state.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: 22,
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          notifier.togglePlayPause();
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Botón Siguiente
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 24),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.skipToNext();
                      },
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowsMiniPlayer(
    BuildContext context,
    AudioPlayerState state,
    AudioPlayer notifier,
  ) {
    return _WindowsPlayerBar(state: state, notifier: notifier);
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
                  padding: EdgeInsets.zero,
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
            if (((!kIsWeb && io.Platform.isWindows) || kIsWeb) &&
                MediaQuery.of(context).size.width > 800) ...[
              IconButton(
                icon: Icon(
                  Icons.shuffle,
                  size: 28,
                  color: state.isShuffleEnabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: () => notifier.toggleShuffle(),
                tooltip: 'Aleatorio',
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 40),
              onPressed: () => notifier.skipToPrevious(),
              tooltip: 'Anterior',
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
                tooltip: state.isPlaying ? 'Pausar' : 'Reproducir',
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 40),
              onPressed: () => notifier.skipToNext(),
              tooltip: 'Siguiente',
            ),
            if (((!kIsWeb && io.Platform.isWindows) || kIsWeb) &&
                MediaQuery.of(context).size.width > 800) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  state.repeatMode.icon,
                  size: 28,
                  color: state.repeatMode != RepeatMode.none
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: () => notifier.toggleRepeatMode(),
                tooltip: 'Repetir',
              ),
            ],
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

class _WindowsPlayerBar extends StatefulWidget {
  final AudioPlayerState state;
  final AudioPlayer notifier;

  const _WindowsPlayerBar({
    required this.state,
    required this.notifier,
  });

  @override
  State<_WindowsPlayerBar> createState() => _WindowsPlayerBarState();
}

class _WindowsPlayerBarState extends State<_WindowsPlayerBar> {
  bool _isScrubberHovered = false;
  double _lastNonZeroVolume = 0.8;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = widget.state.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final primary = theme.colorScheme.primary;
    final volume = widget.state.volume;

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF14171E).withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // 1. INFORMACIÓN DE LA CANCIÓN
          SizedBox(
            width: 280,
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Hero(
                      tag: 'album_art_${track.id}',
                      child: ArtworkWidget(
                        id: track.songId,
                        type: ArtworkType.AUDIO,
                        filePath: track.filePath,
                        width: 58,
                        height: 58,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    if (widget.state.isPlaying)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: AudioVisualizerWidget(
                            isPlaying: true,
                            barCount: 3,
                            height: 12,
                            barWidth: 2,
                            color: primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScrollingText(
                        text: track.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ScrollingText(
                        text: track.artist,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                        duration: const Duration(seconds: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. CONTROLES Y SCRUBBER (Centro)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Fila de botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        size: 20,
                        color: widget.state.isShuffleEnabled
                            ? primary
                            : Colors.white54,
                      ),
                      tooltip: widget.state.isShuffleEnabled
                          ? 'Aleatorio activo'
                          : 'Activar aleatorio',
                      onPressed: () => widget.notifier.toggleShuffle(),
                    ),
                    const SizedBox(width: 8),
                    // Anterior
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 28),
                      color: Colors.white,
                      tooltip: 'Anterior',
                      onPressed: () => widget.notifier.skipToPrevious(),
                    ),
                    const SizedBox(width: 12),
                    // Play / Pause con resplandor moderno
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => widget.notifier.togglePlayPause(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primary,
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(
                                  alpha: widget.state.isPlaying ? 0.45 : 0.2,
                                ),
                                blurRadius: widget.state.isPlaying ? 16 : 8,
                                spreadRadius: widget.state.isPlaying ? 1 : 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.state.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Siguiente
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 28),
                      color: Colors.white,
                      tooltip: 'Siguiente',
                      onPressed: () => widget.notifier.skipToNext(),
                    ),
                    const SizedBox(width: 8),
                    // Repetir
                    IconButton(
                      icon: Icon(
                        widget.state.repeatMode.icon,
                        size: 20,
                        color: widget.state.repeatMode != RepeatMode.none
                            ? primary
                            : Colors.white54,
                      ),
                      tooltip: 'Modo de repetición',
                      onPressed: () => widget.notifier.toggleRepeatMode(),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                // Scrubber interactivo con hover
                MouseRegion(
                  onEnter: (_) => setState(() => _isScrubberHovered = true),
                  onExit: (_) => setState(() => _isScrubberHovered = false),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(widget.state.position),
                        style: TextStyle(
                          color: _isScrubberHovered ? primary : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            trackHeight: _isScrubberHovered ? 5.0 : 3.0,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius:
                                  _isScrubberHovered ? 7.0 : 0.0,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14.0,
                            ),
                            activeTrackColor: primary,
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.15),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: widget.state.progress.clamp(0.0, 1.0),
                            onChanged: (value) {
                              if (widget.state.duration != null) {
                                final position =
                                    widget.state.duration! * value;
                                widget.notifier.seek(position);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatDuration(
                          widget.state.duration ?? Duration.zero,
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. VOLUMEN Y ACCIONES SECUNDARIAS (Derecha)
          SizedBox(
            width: 280,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón Mute / Icono de volumen interactivo
                IconButton(
                  icon: Icon(
                    volume == 0
                        ? Icons.volume_off_rounded
                        : volume < 0.5
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: volume == 0 ? 'Activar sonido' : 'Silenciar',
                  onPressed: () {
                    if (volume > 0) {
                      _lastNonZeroVolume = volume;
                      widget.notifier.setVolume(0.0);
                    } else {
                      widget.notifier.setVolume(_lastNonZeroVolume > 0 ? _lastNonZeroVolume : 0.8);
                    }
                  },
                ),
                // Slider de volumen compacto
                SizedBox(
                  width: 110,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.0,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5.0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10.0,
                      ),
                      activeTrackColor: primary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: volume.clamp(0.0, 1.0),
                      onChanged: (v) => widget.notifier.setVolume(v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Pantalla completa
                IconButton(
                  icon: const Icon(
                    Icons.open_in_full_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  tooltip: 'Pantalla completa',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NowPlayingScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

