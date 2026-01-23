import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zmusic/providers/youtube_provider.dart';

class DownloadStatusBar extends ConsumerWidget {
  const DownloadStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(youTubeDownloadProvider);
    if (downloadState == null) return const SizedBox.shrink();

    final String videoTitle = downloadState.video.title;
    final double progressValue = downloadState.progress;
    final int currentPercentage = (progressValue * 100).toInt();
    final int bytesDownloaded = downloadState.downloadedBytes;
    final int bytesTotal = downloadState.totalBytes;
    final DownloadStatus status = downloadState.status;

    final theme = Theme.of(context);

    // Mapear el estado a texto
    String getStatusText(DownloadStatus status) {
      switch (status) {
        case DownloadStatus.analyzing:
          return 'Analizando enlace...';
        case DownloadStatus.fetchingManifest:
          return 'Obteniendo información...';
        case DownloadStatus.selectingQuality:
          return 'Seleccionando calidad...';
        case DownloadStatus.downloadingThumbnail:
          return 'Descargando portada...';
        case DownloadStatus.downloading:
          return 'Descargando audio...';
        case DownloadStatus.writingMetadata:
          return 'Guardando información...';
        case DownloadStatus.finalizing:
          return 'Finalizando...';
      }
    }

    final statusText = getStatusText(status);

    // Formatear tamaños
    String formatBytes(int bytes) {
      if (bytes <= 0) return '0 B';
      const suffixes = ["B", "KB", "MB", "GB", "TB"];
      var i = (bytes.toString().length - 1) ~/ 3;
      var value = bytes / (1 << (i * 10));
      return "${value.toStringAsFixed(1)} ${suffixes[i]}";
    }

    final downloadedStr = formatBytes(bytesDownloaded);
    final totalStr = formatBytes(bytesTotal);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Icono de nube animado
              const _AnimatedDownloadIcon(),
              const SizedBox(width: 12),
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      videoTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Porcentaje
              Text(
                "$currentPercentage%",
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.1,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          // Tamaños
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "$downloadedStr / $totalStr",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Text(
            'Se guardará automaticamente',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDownloadIcon extends StatefulWidget {
  const _AnimatedDownloadIcon();

  @override
  State<_AnimatedDownloadIcon> createState() => _AnimatedDownloadIconState();
}

class _AnimatedDownloadIconState extends State<_AnimatedDownloadIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // Animación de escala sutil (0.95 a 1.05)
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Calcular la intensidad de la sombra basada en la posición
        final shadowIntensity = 0.15 + (0.1 * _animation.value);
        final shadowBlur = 8.0 + (4.0 * _animation.value);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: shadowIntensity),
                blurRadius: shadowBlur,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withValues(
                      alpha: 0.2 + (0.1 * _animation.value),
                    ),
                    primaryColor.withValues(
                      alpha: 0.05 + (0.05 * _animation.value),
                    ),
                  ],
                  stops: const [0.4, 1.0],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(
                    alpha: 0.3 + (0.2 * _animation.value),
                  ),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.cloud_download_rounded,
                color: primaryColor,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}
