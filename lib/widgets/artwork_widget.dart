import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

/// Provider para obtener los bytes de la carátula de forma asíncrona y cachearla.
/// Esto evita parpadeos al usar Hero y mejora el rendimiento.
final artworkProvider =
    FutureProvider.family<Uint8List?, ({int id, ArtworkType type})>((
      ref,
      arg,
    ) async {
      final OnAudioQuery audioQuery = OnAudioQuery();
      return await audioQuery.queryArtwork(
        arg.id,
        arg.type,
        format: ArtworkFormat.JPEG,
        size: 600,
        quality: 85,
      );
    });

class ArtworkWidget extends ConsumerWidget {
  final int id;
  final ArtworkType type;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final IconData nullIcon;
  final double nullIconSize;

  const ArtworkWidget({
    super.key,
    required this.id,
    required this.type,
    this.width = 50,
    this.height = 50,
    this.borderRadius,
    this.nullIcon = Icons.music_note,
    this.nullIconSize = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(artworkProvider((id: id, type: type)));

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
              // Esto es clave para evitar parpadeos durante la transición Hero
              gaplessPlayback: true,
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
    // Intentamos mantener el tamaño consistente incluso mientras carga
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.5),
        borderRadius: borderRadius,
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
