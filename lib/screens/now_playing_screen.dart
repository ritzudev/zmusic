import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/screens/now_playing/now_playing_mobile.dart';
import 'package:zmusic/screens/now_playing/now_playing_windows.dart';

/// Punto de entrada de la pantalla de reproducción que decide qué vista mostrar
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(audioPlayerProvider.select((s) => s.currentTrack));

    // Si no hay track, mostrar un mensaje simple
    if (track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reproductor')),
        body: const Center(child: Text('No hay música reproduciéndose')),
      );
    }

    // Usar LayoutBuilder para ser aún más óptimos si se redimensiona en desktop
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Si es Windows y hay suficiente espacio horizontal, mostrar vista desktop
          if (Platform.isWindows && constraints.maxWidth > 800) {
            return const NowPlayingWindows();
          }

          // Por defecto (móvil o ventana pequeña en Windows), mostrar vista móvil
          return const NowPlayingMobile();
        },
      ),
    );
  }
}
