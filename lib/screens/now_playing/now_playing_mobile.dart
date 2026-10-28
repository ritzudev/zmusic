import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:zmusic/models/repeat_mode.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/widgets/add_to_playlist_dialog.dart';
import 'package:zmusic/widgets/ambient_glow_background.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/audio_visualizer_widget.dart';
import 'package:zmusic/widgets/scrolling_text.dart';

/// Pantalla de reproducción moderna y cinematográfica optimizada para móviles (Android / iOS)
class NowPlayingMobile extends ConsumerStatefulWidget {
  const NowPlayingMobile({super.key});

  @override
  ConsumerState<NowPlayingMobile> createState() => _NowPlayingMobileState();
}

class _NowPlayingMobileState extends ConsumerState<NowPlayingMobile> {
  bool _isDragging = false;
  double _dragValue = 0.0;

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
    final primaryColor = theme.colorScheme.primary;

    if (track == null) return const SizedBox.shrink();

    final isPlaying = playerState.isPlaying;
    final screenSize = MediaQuery.of(context).size;
    final artSize = (screenSize.width - 72).clamp(200.0, 360.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientGlowBackground(
        accentColor: primaryColor,
        baseColor: const Color(0xFF0A0D14),
        intensity: isPlaying ? 0.35 : 0.18,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Barra Superior con navegación y opciones
              _buildTopBar(context, ref, track, theme),

              // 2. Contenido Principal expandible
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Carátula del Álbum con gestos de deslizamiento y resplandor
                      _buildArtworkHero(
                        context,
                        track,
                        isPlaying,
                        artSize,
                        primaryColor,
                        playerNotifier,
                      ),

                      // Información de la canción (Título, Artista, Favorito)
                      _buildTrackInfo(context, ref, track, theme, isPlaying),

                      // Barra de progreso y scrubber interactivo
                      _buildProgressBar(context, playerState, playerNotifier, theme),

                      // Controles principales de reproducción
                      _buildMainControls(
                        context,
                        playerState,
                        playerNotifier,
                        primaryColor,
                        theme,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Barra inferior de acceso rápido (Cola y Opciones)
              _buildBottomActions(context, ref, track, theme),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra superior elegante con botón para minimizar y opciones rápidas
  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    MusicTrack track,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _GlassButton(
            icon: Icons.keyboard_arrow_down_rounded,
            size: 28,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'REPRODUCIENDO',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              if (track.album != null && track.album!.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    track.album!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          _GlassButton(
            icon: Icons.more_horiz_rounded,
            size: 24,
            onPressed: () => _showTrackOptionsMenu(context, ref, track),
          ),
        ],
      ),
    );
  }

  /// Carátula grande con sombras suaves reactivas y gestos para cambiar de canción
  Widget _buildArtworkHero(
    BuildContext context,
    MusicTrack track,
    bool isPlaying,
    double size,
    Color primaryColor,
    AudioPlayer playerNotifier,
  ) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -250) {
            // Deslizar izquierda -> Siguiente
            HapticFeedback.mediumImpact();
            playerNotifier.skipToNext();
          } else if (details.primaryVelocity! > 250) {
            // Deslizar derecha -> Anterior
            HapticFeedback.mediumImpact();
            playerNotifier.skipToPrevious();
          }
        }
      },
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.92,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: isPlaying ? 0.40 : 0.15),
                blurRadius: isPlaying ? 36 : 20,
                spreadRadius: isPlaying ? 4 : 0,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Hero(
                  tag: 'album_art_${track.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: ArtworkWidget(
                      id: track.songId,
                      type: ArtworkType.AUDIO,
                      filePath: track.filePath,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: BorderRadius.circular(28),
                      nullIconSize: size * 0.38,
                    ),
                  ),
                ),
              ),
              // Borde de brillo sutil
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Título, artista y botón de favoritos con feedback
  Widget _buildTrackInfo(
    BuildContext context,
    WidgetRef ref,
    MusicTrack track,
    ThemeData theme,
    bool isPlaying,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Título y artista
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ScrollingText(
                text: track.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                  fontSize: 22,
                ),
                duration: const Duration(seconds: 14),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (isPlaying) ...[
                    AudioVisualizerWidget(
                      isPlaying: isPlaying,
                      barCount: 3,
                      height: 13,
                      barWidth: 2.5,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ScrollingText(
                      text: track.artist.isNotEmpty
                          ? track.artist
                          : 'Artista desconocido',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      duration: const Duration(seconds: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Botón de Favorito animado
        Consumer(
          builder: (context, ref, _) {
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

            return InkResponse(
              onTap: () {
                HapticFeedback.lightImpact();
                ref
                    .read(musicLibraryProvider.notifier)
                    .toggleFavorite(track.id);
              },
              radius: 26,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFavorite
                      ? Colors.red.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                child: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? Colors.redAccent : Colors.white70,
                  size: 26,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Barra de progreso fluida con tiempo transcurrido y restante
  Widget _buildProgressBar(
    BuildContext context,
    AudioPlayerState playerState,
    AudioPlayer playerNotifier,
    ThemeData theme,
  ) {
    final currentPos = _isDragging
        ? Duration(milliseconds: _dragValue.toInt())
        : playerState.position;
    final totalDuration = playerState.duration ?? Duration.zero;
    final maxMs = totalDuration.inMilliseconds.toDouble();
    final clampedValue = maxMs > 0
        ? currentPos.inMilliseconds.toDouble().clamp(0.0, maxMs)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.5,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6.5,
              elevation: 4,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: clampedValue,
            min: 0.0,
            max: maxMs > 0 ? maxMs : 1.0,
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragValue = val;
              });
            },
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              setState(() {
                _isDragging = false;
              });
              playerNotifier.seek(Duration(milliseconds: val.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(currentPos),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 12,
                ),
              ),
              Text(
                totalDuration > Duration.zero
                    ? '-${_formatDuration(totalDuration - currentPos)}'
                    : '0:00',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fila de controles principales: Shuffle, Anterior, Play/Pause, Siguiente, Repetir
  Widget _buildMainControls(
    BuildContext context,
    AudioPlayerState playerState,
    AudioPlayer playerNotifier,
    Color primaryColor,
    ThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle
        IconButton(
          icon: Icon(
            Icons.shuffle_rounded,
            size: 26,
            color: playerState.isShuffleEnabled
                ? primaryColor
                : Colors.white.withValues(alpha: 0.4),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            playerNotifier.toggleShuffle();
          },
        ),

        // Anterior
        IconButton(
          icon: const Icon(
            Icons.skip_previous_rounded,
            size: 38,
            color: Colors.white,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            playerNotifier.skipToPrevious();
          },
        ),

        // Play / Pause central grande con Glow
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            playerNotifier.togglePlayPause();
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 42,
                color: Colors.black87,
              ),
            ),
          ),
        ),

        // Siguiente
        IconButton(
          icon: const Icon(
            Icons.skip_next_rounded,
            size: 38,
            color: Colors.white,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            playerNotifier.skipToNext();
          },
        ),

        // Repetir
        IconButton(
          icon: Icon(
            playerState.repeatMode.icon,
            size: 26,
            color: playerState.repeatMode != RepeatMode.none
                ? primaryColor
                : Colors.white.withValues(alpha: 0.4),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            playerNotifier.toggleRepeatMode();
          },
        ),
      ],
    );
  }

  /// Barra inferior con botón de lista/cola y temporizador/detalles
  Widget _buildBottomActions(
    BuildContext context,
    WidgetRef ref,
    MusicTrack track,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Añadir a playlist
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.playlist_add_rounded, size: 20),
            label: const Text('Playlist', style: TextStyle(fontSize: 13)),
            onPressed: () => AddToPlaylistDialog.show(context, track),
          ),

          // Abrir Cola de reproducción
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            icon: const Icon(Icons.queue_music_rounded, size: 20),
            label: const Text(
              'Cola',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => _showPlaylist(context, ref),
          ),
        ],
      ),
    );
  }

  /// Menú modal con opciones de la canción actual
  void _showTrackOptionsMenu(
    BuildContext context,
    WidgetRef ref,
    MusicTrack track,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ArtworkWidget(
                    id: track.songId,
                    type: ArtworkType.AUDIO,
                    filePath: track.filePath,
                    width: 48,
                    height: 48,
                  ),
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('Añadir a playlist'),
                onTap: () {
                  Navigator.pop(context);
                  AddToPlaylistDialog.show(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Detalles del archivo'),
                onTap: () {
                  Navigator.pop(context);
                  _showSongDetailsDialog(context, track);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Diálogo con información técnica de la canción
  void _showSongDetailsDialog(BuildContext context, MusicTrack track) {
    final sizeMb = track.size != null
        ? '${(track.size! / (1024 * 1024)).toStringAsFixed(2)} MB'
        : 'Desconocido';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Detalles de la Canción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Título:', track.title),
            _buildDetailRow('Artista:', track.artist),
            _buildDetailRow('Álbum:', track.album ?? 'Desconocido'),
            _buildDetailRow('Duración:', track.formattedDuration),
            _buildDetailRow('Tamaño:', sizeMb),
            _buildDetailRow('Ruta:', track.filePath),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          text: '$label ',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modal Bottom Sheet de la Cola de reproducción mejorado
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
          final primaryColor = Theme.of(context).colorScheme.primary;

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFF12151D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Barra de arrastre
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Encabezado
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Cola de Reproducción',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${playlist.length} temas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Colors.white10),

                // Lista de canciones
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final track = playlist[index];
                      final isCurrent = index == currentIndex;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? primaryColor.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: isCurrent
                              ? Border.all(
                                  color: primaryColor.withValues(alpha: 0.35),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: Stack(
                            alignment: Alignment.center,
                            children: [
                              ArtworkWidget(
                                id: track.songId,
                                type: ArtworkType.AUDIO,
                                filePath: track.filePath,
                                width: 44,
                                height: 44,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              if (isCurrent)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.equalizer_rounded,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isCurrent ? primaryColor : Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? primaryColor.withValues(alpha: 0.8)
                                  : Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Text(
                            track.formattedDuration,
                            style: TextStyle(
                              color: isCurrent
                                  ? primaryColor
                                  : Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            playerNotifier.playTrack(index);
                            Navigator.pop(context);
                          },
                        ),
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

/// Botón con aspecto de cristal sutil
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _GlassButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 24,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
