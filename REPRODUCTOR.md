# ZMusic - Reproductor de Música con just_audio y audio_service

## 🎵 Características Implementadas

### ✅ Reproducción de Audio
- **just_audio**: Motor de reproducción de audio de alta calidad
- **audio_service**: Reproducción en segundo plano con controles en pantalla de bloqueo
- Soporte para múltiples formatos de audio (MP3, WAV, OGG, etc.)

### ✅ Funcionalidades del Reproductor
- ▶️ Play/Pause
- ⏭️ Siguiente canción
- ⏮️ Canción anterior
- 🔄 Reproducción automática de lista
- 📊 Barra de progreso interactiva
- ⏱️ Visualización de tiempo transcurrido y restante

### ✅ Interfaz de Usuario
- **Mini Player**: Barra de reproducción flotante en la pantalla principal
- **Pantalla Completa**: Vista detallada del reproductor con carátula
- **Lista de Reproducción**: Modal con todas las canciones de la cola
- **Indicadores Visuales**: Muestra qué canción está reproduciéndose actualmente
- **Animaciones**: Transiciones suaves y efectos visuales modernos

### ✅ Reproducción en Segundo Plano
- Continúa reproduciendo cuando la app está en segundo plano
- Controles en la pantalla de bloqueo
- Notificación persistente con información de la canción
- Controles en la notificación (Play/Pause, Siguiente, Anterior)

## 📁 Estructura de Archivos Creados

```
lib/
├── services/
│   └── audio_handler_service.dart    # Servicio de audio con audio_service
├── providers/
│   ├── audio_player_provider.dart    # Provider de Riverpod para el reproductor
│   └── audio_player_provider.g.dart  # Código generado
├── widgets/
│   └── music_player_controls.dart    # Controles de reproducción (mini y completo)
└── screens/
    └── now_playing_screen.dart       # Pantalla completa del reproductor
```

## 🚀 Cómo Usar

### 1. Reproducir Música
- Toca cualquier canción en la lista para comenzar a reproducir
- La lista completa se cargará como cola de reproducción
- El mini player aparecerá en la parte inferior

### 2. Controles del Mini Player
- **Toca el mini player** para abrir la pantalla completa
- **Botón Play/Pause** para controlar la reproducción
- **Botones Anterior/Siguiente** para navegar entre canciones

### 3. Pantalla Completa
- **Desliza hacia abajo** o toca la flecha para cerrar
- **Barra de progreso** arrastrala para buscar en la canción
- **Botón de playlist** para ver y seleccionar otras canciones
- **Controles adicionales** (shuffle, repeat - próximamente)

### 4. Reproducción en Segundo Plano
- La música continúa cuando minimizas la app
- Usa los controles de la pantalla de bloqueo
- Controla desde la notificación

## 🔧 Configuración Técnica

### Dependencias Agregadas
```yaml
dependencies:
  just_audio: ^0.9.42          # Motor de reproducción
  audio_service: ^0.18.15      # Reproducción en segundo plano
  rxdart: ^0.28.0              # Streams reactivos
```

### Permisos de Android
Se agregaron los siguientes permisos en `AndroidManifest.xml`:
- `WAKE_LOCK`: Mantener el dispositivo despierto durante reproducción
- `FOREGROUND_SERVICE`: Permitir servicio en primer plano
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: Servicio de reproducción de medios

### Servicios de Android
- **AudioService**: Servicio de reproducción en segundo plano
- **MediaButtonReceiver**: Receptor de botones de medios (auriculares, bluetooth)

## 📱 Características Futuras Sugeridas

### Próximas Mejoras
- [ ] **Shuffle**: Reproducción aleatoria
- [ ] **Repeat**: Modos de repetición (una, todas, ninguna)
- [ ] **Favoritos**: Marcar canciones favoritas
- [ ] **Playlists**: Crear y gestionar listas de reproducción personalizadas
- [ ] **Ecualizador**: Ajustes de audio
- [ ] **Sleep Timer**: Temporizador de apagado
- [ ] **Letras**: Mostrar letras de canciones
- [ ] **Búsqueda**: Buscar canciones en la biblioteca
- [ ] **Filtros**: Filtrar por artista, álbum, género

### Mejoras de UI/UX
- [ ] **Animación de carátula**: Rotación durante reproducción
- [ ] **Visualizador de audio**: Barras de frecuencia animadas
- [ ] **Temas**: Colores dinámicos basados en la carátula
- [ ] **Gestos**: Deslizar para cambiar de canción
- [ ] **Widgets**: Widget de pantalla de inicio

## 🐛 Solución de Problemas

### La música no se reproduce
1. Verifica que los permisos de audio estén otorgados
2. Asegúrate de que el archivo de audio existe y es válido
3. Revisa los logs para errores específicos

### No aparecen controles en la pantalla de bloqueo
1. Verifica que los permisos estén en el AndroidManifest.xml
2. Asegúrate de que audio_service está inicializado correctamente
3. Comprueba que el servicio está ejecutándose en segundo plano

### Errores de compilación
1. Ejecuta `flutter pub get`
2. Ejecuta `dart run build_runner build --delete-conflicting-outputs`
3. Limpia el proyecto: `flutter clean && flutter pub get`

## 📝 Notas Técnicas

### Arquitectura
- **Riverpod**: Gestión de estado reactiva
- **audio_service**: Integración con el sistema de medios del OS
- **just_audio**: Reproducción de audio de bajo nivel
- **Streams**: Comunicación reactiva entre componentes

### Flujo de Datos
1. Usuario toca una canción → `_MusicCard`
2. Se llama a `audioPlayerProvider.setPlaylistAndPlay()`
3. `MusicAudioHandler` carga el archivo y configura `just_audio`
4. Los streams actualizan la UI automáticamente
5. `audio_service` sincroniza con el sistema de medios

### Rendimiento
- Los streams se actualizan solo cuando cambian los valores
- Las imágenes de carátula se cargan de forma perezosa
- La lista de reproducción usa ListView.builder para eficiencia

## 🎨 Personalización

### Cambiar Colores del Reproductor
Edita `lib/theme/app_theme.dart` para personalizar los colores del tema.

### Modificar Controles
Edita `lib/widgets/music_player_controls.dart` para cambiar el diseño de los controles.

### Ajustar Comportamiento
Edita `lib/services/audio_handler_service.dart` para cambiar el comportamiento de reproducción.

---

**¡Disfruta de tu música con ZMusic! 🎵**
