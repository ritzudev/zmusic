# Diagnóstico: Problema de Descarga de YouTube

## 🔍 Síntomas Observados
El proceso de descarga se detiene en:
```
YT_DEBUG: Iniciando flujo de datos (esperando primer chunk)...
```

## 🎯 Causas Probables

### 1. **Timeout de Red (MÁS PROBABLE)**
- El stream HTTP no responde o tarda demasiado
- No hay timeout configurado, causando espera indefinida
- **Solución implementada**: Timeout de 30 segundos

### 2. **Bloqueo de Cleartext Traffic**
- Android 9+ bloquea HTTP por defecto
- YouTube puede usar URLs HTTP en algunos casos
- **Solución implementada**: `network_security_config.xml`

### 3. **Problemas de Conectividad**
- Conexión de red inestable
- Firewall o proxy bloqueando la conexión
- VPN interfiriendo con las peticiones

### 4. **Limitación de YouTube**
- YouTube detectando y bloqueando peticiones automatizadas
- Rate limiting por demasiadas peticiones
- IP bloqueada temporalmente

### 5. **Problema con youtube_explode_dart**
- Bug en la librería
- Incompatibilidad con la versión actual de YouTube
- Headers HTTP incorrectos

## ✅ Cambios Implementados

### 1. Timeouts Explícitos
```dart
// Timeout para obtener manifiesto (15 segundos)
final manifest = await _yt.videos.streamsClient.getManifest(video.id).timeout(
  const Duration(seconds: 15),
);

// Timeout para el stream de datos (30 segundos)
await for (final data in stream.timeout(
  const Duration(seconds: 30),
)) { ... }
```

### 2. Configuración de Seguridad de Red
- Archivo: `android/app/src/main/res/xml/network_security_config.xml`
- Permite cleartext traffic cuando sea necesario
- Mantiene HTTPS para dominios de YouTube

### 3. Logs Mejorados
- URL del stream
- Tamaño total del archivo
- Información detallada del stream seleccionado
- Progreso en MB
- Detección de timeouts

### 4. Limpieza de Archivos Parciales
- Si la descarga falla, se elimina el archivo parcial
- Evita archivos corruptos en el dispositivo

## 🧪 Próximos Pasos para Diagnosticar

### Prueba 1: Verificar Logs Nuevos
Ejecuta la app y busca estos nuevos logs:
```
YT_DEBUG: Manifiesto obtenido exitosamente
YT_DEBUG: Streams MP4 disponibles: X
YT_DEBUG: Stream seleccionado:
  - Bitrate: ...
  - Tamaño: ... MB
  - Codec: ...
YT_DEBUG: URL del stream: ...
YT_DEBUG: Tamaño total esperado: ... MB
```

### Prueba 2: Verificar Timeout
Si ves este mensaje después de 30 segundos:
```
YT_DEBUG: TIMEOUT - No se recibió respuesta del servidor
```
Entonces el problema es de conectividad con YouTube.

### Prueba 3: Verificar Conectividad
En el dispositivo, abre un navegador y prueba:
1. Abrir youtube.com
2. Reproducir un video
3. Verificar que no estés usando VPN

## 🔧 Soluciones Adicionales si el Problema Persiste

### Opción 1: Usar User-Agent Personalizado
Si YouTube está bloqueando las peticiones, podemos agregar headers personalizados.

### Opción 2: Actualizar youtube_explode_dart
```bash
flutter pub upgrade youtube_explode_dart
```

### Opción 3: Implementar Reintentos
Agregar lógica de retry con backoff exponencial.

### Opción 4: Usar API Alternativa
Considerar usar `yt-dlp` a través de FFI o una API backend.

### Opción 5: Verificar Permisos de Red
Asegurarse de que la app tenga acceso a internet:
- Configuración > Apps > Z Music > Permisos > Red

## 📊 Información para Reportar

Si el problema persiste, necesitamos:
1. ✅ Los nuevos logs completos
2. ✅ Versión de Android
3. ✅ ¿Estás usando VPN?
4. ✅ ¿Funciona con WiFi y datos móviles?
5. ✅ ¿Qué video estás intentando descargar?

## 🎬 Cómo Probar

1. **Reconstruir la app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Intentar descargar un video corto** (menos de 5 MB)

3. **Observar los logs** en tiempo real

4. **Reportar qué mensaje aparece** después de "Iniciando flujo de datos..."
