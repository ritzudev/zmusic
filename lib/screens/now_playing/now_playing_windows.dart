import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/models/repeat_mode.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/widgets/ambient_glow_background.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/audio_visualizer_widget.dart';
import 'package:zmusic/widgets/scrolling_text.dart';
import 'package:zmusic/widgets/windows_title_bar.dart';

/// Versión cinematográfica y moderna para Windows de la pantalla completa
class NowPlayingWindows extends ConsumerStatefulWidget {
  const NowPlayingWindows({super.key});

  @override
  ConsumerState<NowPlayingWindows> createState() => _NowPlayingWindowsState();
}

class _NowPlayingWindowsState extends ConsumerState<NowPlayingWindows> {
  bool _isScrubberHovered = false;
  double _lastVolume = 0.8;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final playerNotifier = ref.read(audioPlayerProvider.notifier);
    final track = playerState.currentTrack;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (track == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientGlowBackground(
        accentColor: primary,
        baseColor: const Color(0xFF090B10),
        intensity: playerState.isPlaying ? 0.30 : 0.15,
        child: Column(
          children: [
            // 1. BARRA SUPERIOR CON TITLE BAR Y BOTÓN SALIR
            WindowsTitleBar(
              height: 48,
              backgroundColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    // Botón volver
                    _GlassIconButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      tooltip: 'Minimizar pantalla completa (Esc)',
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'EN REPRODUCCIÓN',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white60,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. CONTENIDO PRINCIPAL EN 2 COLUMNAS (Hero y Cola)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // COLUMNA IZQUIERDA: Portada Hero, Título, Artista, Visualizador
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Portada grande con efecto resplandor
                            Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                  maxHeight: 420,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(
                                        alpha: playerState.isPlaying ? 0.45 : 0.2,
                                      ),
                                      blurRadius: 48,
                                      spreadRadius: 4,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(
                                    children: [
                                      ArtworkWidget(
                                        id: track.songId,
                                        type: ArtworkType.AUDIO,
                                        filePath: track.filePath,
                                        width: double.infinity,
                                        height: double.infinity,
                                        borderRadius: BorderRadius.circular(24),
                                        nullIconSize: 120,
                                      ),
                                      // Borde brillante de cristal
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.15,
                                              ),
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Fila de Título y Favorito
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ScrollingText(
                                        text: track.title,
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ScrollingText(
                                        text: track.artist,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        duration: const Duration(seconds: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Botón Favorito estilizado
                                _GlassIconButton(
                                  icon: track.isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  iconColor: track.isFavorite
                                      ? Colors.redAccent
                                      : Colors.white70,
                                  tooltip: track.isFavorite
                                      ? 'Quitar de favoritos'
                                      : 'Marcar como favorita',
                                  size: 46,
                                  onPressed: () {
                                    ref
                                        .read(musicLibraryProvider.notifier)
                                        .toggleFavorite(track.id);
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Barra de detalles / Visualizador
                            Row(
                              children: [
                                if (track.album != null &&
                                    track.album!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.album_rounded,
                                          size: 14,
                                          color: Colors.white60,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          track.album!,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (playerState.isPlaying)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AudioVisualizerWidget(
                                          isPlaying: true,
                                          barCount: 5,
                                          height: 14,
                                          barWidth: 2.5,
                                          color: primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'REPRODUCIENDO',
                                          style: TextStyle(
                                            color: primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // COLUMNA DERECHA: Pestaña Cola de Reproducción
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF131620).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cabecera de la lista
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                              child: Row(
                                children: [
                                  Text(
                                    'COLA DE REPRODUCCIÓN',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${playerState.playlist.length} canciones',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
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

                            // Lista de pistas en la cola
                            Expanded(
                              child: _buildQueueList(
                                context,
                                ref,
                                playerState,
                                playerNotifier,
                                primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. BARRA FLOTANTE DE CONTROLES INFERIOR
            Container(
              margin: const EdgeInsets.fromLTRB(40, 0, 40, 24),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF141722).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrubber con Hover y Tooltips
                  MouseRegion(
                    onEnter: (_) => setState(() => _isScrubberHovered = true),
                    onExit: (_) => setState(() => _isScrubberHovered = false),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(playerState.position),
                          style: TextStyle(
                            color:
                                _isScrubberHovered ? primary : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: _isScrubberHovered ? 6.0 : 3.5,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius:
                                    _isScrubberHovered ? 8.0 : 4.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16.0,
                              ),
                              activeTrackColor: primary,
                              inactiveTrackColor:
                                  Colors.white.withValues(alpha: 0.15),
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: playerState.progress.clamp(0.0, 1.0),
                              onChanged: (value) {
                                if (playerState.duration != null) {
                                  final position =
                                      playerState.duration! * value;
                                  playerNotifier.seek(position);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _formatDuration(
                            playerState.duration ?? Duration.zero,
                          ),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Fila de botones principales y volumen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Acciones izquierdas (Shuffle y Repeat)
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: Icons.shuffle_rounded,
                            iconColor: playerState.isShuffleEnabled
                                ? primary
                                : Colors.white60,
                            tooltip: playerState.isShuffleEnabled
                                ? 'Desactivar aleatorio'
                                : 'Activar aleatorio',
                            onPressed: () => playerNotifier.toggleShuffle(),
                          ),
                          const SizedBox(width: 8),
                          _GlassIconButton(
                            icon: playerState.repeatMode.icon,
                            iconColor: playerState.repeatMode !=
                                    RepeatMode.none
                                ? primary
                                : Colors.white60,
                            tooltip: 'Modo de repetición',
                            onPressed: () =>
                                playerNotifier.toggleRepeatMode(),
                          ),
                        ],
                      ),

                      // Botones de reproducción centrales
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: Icons.skip_previous_rounded,
                            size: 44,
                            iconSize: 26,
                            tooltip: 'Pista anterior',
                            onPressed: () => playerNotifier.skipToPrevious(),
                          ),
                          const SizedBox(width: 16),
                          // Botón Play / Pause principal con resplandor
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => playerNotifier.togglePlayPause(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withValues(
                                        alpha: playerState.isPlaying ? 0.5 : 0.25,
                                      ),
                                      blurRadius:
                                          playerState.isPlaying ? 24 : 12,
                                      spreadRadius:
                                          playerState.isPlaying ? 2 : 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  playerState.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          _GlassIconButton(
                            icon: Icons.skip_next_rounded,
                            size: 44,
                            iconSize: 26,
                            tooltip: 'Siguiente pista',
                            onPressed: () => playerNotifier.skipToNext(),
                          ),
                        ],
                      ),

                      // Control de volumen derecho
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: playerState.volume == 0
                                ? Icons.volume_off_rounded
                                : playerState.volume < 0.5
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded,
                            tooltip: playerState.volume == 0
                                ? 'Activar sonido'
                                : 'Silenciar',
                            onPressed: () {
                              if (playerState.volume > 0) {
                                _lastVolume = playerState.volume;
                                playerNotifier.setVolume(0.0);
                              } else {
                                playerNotifier.setVolume(
                                  _lastVolume > 0 ? _lastVolume : 0.8,
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5.5,
                                ),
                                activeTrackColor: primary,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.15),
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: playerState.volume.clamp(0.0, 1.0),
                                onChanged: (v) => playerNotifier.setVolume(v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList(
    BuildContext context,
    WidgetRef ref,
    AudioPlayerState playerState,
    AudioPlayer playerNotifier,
    Color primary,
  ) {
    final playlist = playerState.playlist;
    final currentIndex = playerState.currentIndex;

    if (playlist.isEmpty) {
      return const Center(
        child: Text(
          'No hay canciones en la cola',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: playlist.length,
      itemBuilder: (context, index) {
        final track = playlist[index];
        final isCurrent = index == currentIndex;

        return _QueueTile(
          track: track,
          index: index,
          isCurrent: isCurrent,
          isPlaying: isCurrent && playerState.isPlaying,
          primaryColor: primary,
          onTap: () => playerNotifier.playTrack(index),
        );
      },
    );
  }
}

class _QueueTile extends StatefulWidget {
  final MusicTrack track;
  final int index;
  final bool isCurrent;
  final bool isPlaying;
  final Color primaryColor;
  final VoidCallback onTap;

  const _QueueTile({
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.isPlaying,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
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
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isCurrent
                ? widget.primaryColor.withValues(alpha: 0.15)
                : _isHovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isCurrent
                  ? widget.primaryColor.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Indicador o Visualizador
              SizedBox(
                width: 28,
                child: widget.isPlaying
                    ? AudioVisualizerWidget(
                        isPlaying: true,
                        barCount: 3,
                        height: 12,
                        barWidth: 2,
                        color: widget.primaryColor,
                      )
                    : Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          color: widget.isCurrent
                              ? widget.primaryColor
                              : Colors.white38,
                          fontSize: 12,
                          fontWeight: widget.isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
              ),

              // Portada pequeña
              ArtworkWidget(
                id: widget.track.songId,
                type: ArtworkType.AUDIO,
                filePath: widget.track.filePath,
                width: 38,
                height: 38,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.title,
                      style: TextStyle(
                        color: widget.isCurrent
                            ? widget.primaryColor
                            : Colors.white,
                        fontWeight: widget.isCurrent
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
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Duración
              Text(
                widget.track.formattedDuration,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? iconColor;
  final double size;
  final double iconSize;

  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor,
    this.size = 38,
    this.iconSize = 20,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: widget.iconColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
