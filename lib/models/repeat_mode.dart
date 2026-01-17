import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

enum RepeatMode { none, one, all }

extension RepeatModeExtension on RepeatMode {
  // Obtener el siguiente modo al presionar el botón
  RepeatMode get next {
    switch (this) {
      case RepeatMode.none:
        return RepeatMode.all;
      case RepeatMode.all:
        return RepeatMode.one;
      case RepeatMode.one:
        return RepeatMode.none;
    }
  }

  // Icono para mostrar en la UI
  IconData get icon {
    switch (this) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
      case RepeatMode.all:
        return Icons.repeat;
    }
  }

  // Descripción legible
  String get description {
    switch (this) {
      case RepeatMode.none:
        return 'No repetir';
      case RepeatMode.one:
        return 'Repetir una';
      case RepeatMode.all:
        return 'Repetir todo';
    }
  }

  // Convertir a AudioServiceRepeatMode
  AudioServiceRepeatMode toAudioServiceMode() {
    switch (this) {
      case RepeatMode.none:
        return AudioServiceRepeatMode.none;
      case RepeatMode.all:
        return AudioServiceRepeatMode.all;
      case RepeatMode.one:
        return AudioServiceRepeatMode.one;
    }
  }
}
