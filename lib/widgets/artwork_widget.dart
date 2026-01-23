import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'dart:io';

/// Provider para obtener los bytes de la carátula de forma asíncrona y cachearla.
/// Ahora incluye un FALLBACK para leer directamente del archivo si MediaStore falla.
final artworkProvider =
    FutureProvider.family<
      Uint8List?,
      ({int id, ArtworkType type, String? filePath})
    >((ref, arg) async {
      try {
        debugPrint(
          'YT_DEBUG: Querying artwork for ID: ${arg.id}, Type: ${arg.type}',
        );

        // 1. Intentar con on_audio_query
        if (Platform.isAndroid) {
          final audioStatus = await Permission.audio.status;
          final storageStatus = await Permission.storage.status;

          if (audioStatus.isGranted || storageStatus.isGranted) {
            final OnAudioQuery audioQuery = OnAudioQuery();
            final bytes = await audioQuery.queryArtwork(
              arg.id,
              arg.type,
              format: ArtworkFormat.JPEG,
              size: 600,
              quality: 85,
            );

            if (bytes != null && bytes.isNotEmpty) {
              debugPrint(
                'YT_DEBUG: Artwork Found via MediaStore for ${arg.id}',
              );
              return bytes;
            }
          }
        }

        // 2. FALLBACK: Leer directamente del archivo
        if (arg.filePath != null && await File(arg.filePath!).exists()) {
          debugPrint('YT_DEBUG: Fallback lectura directa: ${arg.filePath}');
          final file = File(arg.filePath!);
          final metadata = readMetadata(file, getImage: true);

          if (metadata.pictures.isNotEmpty) {
            final bytes = metadata.pictures.first.bytes;
            debugPrint(
              'YT_DEBUG: Artwork Found via Direct Reading (${bytes.length} bytes)',
            );
            return bytes;
          }
        }

        return null;
      } catch (e) {
        debugPrint("YT_DEBUG: Error artwork fallback: $e");
        return null;
      }
    });

class ArtworkWidget extends ConsumerWidget {
  final int id;
  final ArtworkType type;
  final String? filePath;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final IconData nullIcon;
  final double nullIconSize;

  const ArtworkWidget({
    super.key,
    required this.id,
    required this.type,
    this.filePath,
    this.width = 50,
    this.height = 50,
    this.borderRadius,
    this.nullIcon = Icons.music_note,
    this.nullIconSize = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(
      artworkProvider((id: id, type: type, filePath: filePath)),
    );

    return artworkAsync.when(
      data: (bytes) {
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: Image.memory(
              bytes,
              width: width,
              height: height,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          );
        }
        return _buildNullArtwork(context);
      },
      loading: () => _buildLoadingArtwork(context),
      error: (_, __) => _buildNullArtwork(context),
    );
  }

  Widget _buildNullArtwork(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: borderRadius,
      ),
      child: Icon(nullIcon, size: nullIconSize, color: Colors.white),
    );
  }

  Widget _buildLoadingArtwork(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.5),
        borderRadius: borderRadius,
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
