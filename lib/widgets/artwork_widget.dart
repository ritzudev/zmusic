import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Provider para obtener los bytes de la carátula de forma asíncrona y cachearla.
/// Esto evita parpadeos al usar Hero y mejora el rendimiento.
final artworkProvider =
    FutureProvider.family<Uint8List?, ({int id, ArtworkType type})>((
      ref,
      arg,
    ) async {
      try {
        // En Android 13+, necesitamos permiso de AUDIO. En anteriores, STORAGE.
        // El plugin on_audio_query_pluse a veces crashea si se llama sin permisos.
        if (Platform.isAndroid) {
          final audioStatus = await Permission.audio.status;
          final storageStatus = await Permission.storage.status;

          if (!audioStatus.isGranted && !storageStatus.isGranted) {
            return null;
          }
        }

        final OnAudioQuery audioQuery = OnAudioQuery();
        return await audioQuery.queryArtwork(
          arg.id,
          arg.type,
          format: ArtworkFormat.JPEG,
          size: 600,
          quality: 85,
        );
      } catch (e) {
        debugPrint("Error al cargar artwork para ${arg.id}: $e");
        return null;
      }
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
