import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/screens/now_playing/now_playing_mobile.dart';
import 'package:zmusic/screens/now_playing/now_playing_windows.dart';

/// Punto de entrada de la pantalla de reproducción que decide qué vista mostrar
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _forceMobileView = false;

  @override
  Widget build(BuildContext context) {
    final track = ref.watch(audioPlayerProvider.select((s) => s.currentTrack));

    // Si no hay track, mostrar un mensaje simple
    if (track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reproductor')),
        body: const Center(child: Text('No hay música reproduciéndose')),
      );
    }

    // Usar LayoutBuilder para ser óptimos si se redimensiona en desktop
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = Platform.isWindows && constraints.maxWidth > 750;

          // Vista normal de escritorio
          if (isDesktop && !_forceMobileView) {
            return Stack(
              children: [
                const NowPlayingWindows(),

                // Botón para alternar a previsualización de vista móvil en Windows
                Positioned(
                  top: 10,
                  right: 155, // Antes de los controles de ventana
                  child: Tooltip(
                    message: 'Previsualizar vista móvil',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _forceMobileView = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.smartphone_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Vista móvil',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Si estamos forzando la vista móvil en pantalla ancha de Windows
          if (Platform.isWindows && constraints.maxWidth > 500) {
            return Stack(
              children: [
                // Fondo oscuro ambiental
                Container(color: const Color(0xFF080A0F)),

                // Mockup centrado de móvil
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 860,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.7),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const NowPlayingMobile(),
                  ),
                ),

                // Botón para volver a vista de escritorio
                Positioned(
                  top: 16,
                  right: 20,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    onPressed: () => setState(() => _forceMobileView = false),
                    icon: const Icon(Icons.desktop_windows_rounded, size: 16),
                    label: const Text(
                      'Vista escritorio',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Vista móvil pura (Android/iOS o ventana angosta en Windows)
          return const NowPlayingMobile();
        },
      ),
    );
  }
}
