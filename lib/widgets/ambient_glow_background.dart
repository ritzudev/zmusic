import 'dart:ui';
import 'package:flutter/material.dart';

class AmbientGlowBackground extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final Color baseColor;
  final double intensity;

  const AmbientGlowBackground({
    super.key,
    required this.child,
    this.accentColor = const Color(0xFF1DB954),
    this.baseColor = const Color(0xFF0A0D14),
    this.intensity = 0.28,
  });

  @override
  Widget build(BuildContext context) {
    // Generar un color análogo / complementario para dar riqueza cromática
    final HSLColor hsl = HSLColor.fromColor(accentColor);
    final secondaryHue = (hsl.hue + 35) % 360;
    final secondaryColor = hsl.withHue(secondaryHue).withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0)).toColor();

    return Stack(
      children: [
        // Color base de fondo profundo
        Positioned.fill(
          child: Container(color: baseColor),
        ),

        // Glow ambiental superior izquierdo (Color principal)
        Positioned(
          top: -100,
          left: -60,
          width: 550,
          height: 550,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: accentColor.withValues(alpha: intensity),
              end: accentColor.withValues(alpha: intensity),
            ),
            duration: const Duration(milliseconds: 700),
            builder: (context, color, _) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color ?? Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Glow ambiental central (Color secundario enriquecido)
        Positioned(
          top: 150,
          right: 200,
          width: 450,
          height: 450,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: secondaryColor.withValues(alpha: intensity * 0.7),
              end: secondaryColor.withValues(alpha: intensity * 0.7),
            ),
            duration: const Duration(milliseconds: 700),
            builder: (context, color, _) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color ?? Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Glow ambiental inferior derecho
        Positioned(
          bottom: -80,
          right: -80,
          width: 650,
          height: 650,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: accentColor.withValues(alpha: intensity * 0.75),
              end: accentColor.withValues(alpha: intensity * 0.75),
            ),
            duration: const Duration(milliseconds: 700),
            builder: (context, color, _) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color ?? Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Capa de desenfoque de cristal (Backdrop Blur)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: const SizedBox.expand(),
          ),
        ),

        // Contenido por encima
        Positioned.fill(child: child),
      ],
    );
  }
}
