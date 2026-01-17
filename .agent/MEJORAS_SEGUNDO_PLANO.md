# Mejoras para Reproducción en Segundo Plano

## Problema
La aplicación se cerraba automáticamente después de aproximadamente 1 hora de estar en segundo plano, interrumpiendo la reproducción de música.

## Causa
Android implementa restricciones agresivas de batería que matan servicios en segundo plano después de cierto tiempo, especialmente en dispositivos con Android 6.0 (Marshmallow) o superior.

## Soluciones Implementadas

### 1. Permisos Adicionales en AndroidManifest.xml

#### REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```
Permite solicitar al usuario que excluya la app de las optimizaciones de batería.

#### RECEIVE_BOOT_COMPLETED
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
Útil para servicios persistentes (aunque no lo usamos actualmente).

### 2. Configuración del AudioService

#### stopWithTask="false"
```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:stopWithTask="false"
    ...>
```
**Crítico**: Evita que el servicio se detenga cuando el usuario cierra la app desde la lista de aplicaciones recientes.

### 3. Mejoras en AudioServiceConfig

```dart
AudioServiceConfig(
  androidStopForegroundOnPause: false,  // Mantener notificación al pausar
  androidNotificationOngoing: true,      // Notificación persistente
  preloadArtwork: true,                  // Pre-cargar artwork
  ...
)
```

- **androidStopForegroundOnPause: false**: Mantiene la notificación visible incluso cuando la música está en pausa, lo que ayuda a mantener el servicio activo.
- **androidNotificationOngoing: true**: Hace que la notificación sea persistente y más difícil de eliminar.

### 4. Modificación de onTaskRemoved()

```dart
@override
Future<void> onTaskRemoved() async {
  // NO detener la reproducción cuando se cierra la app
  // El usuario puede detenerla desde la notificación
}
```

Antes detenía la reproducción al cerrar la app. Ahora permite que continúe.

### 5. Solicitud de Exclusión de Batería (MainActivity.kt)

Al iniciar la app, se solicita automáticamente al usuario que excluya Z Music de las optimizaciones de batería:

```kotlin
private fun requestBatteryOptimizationExemption() {
    if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
        // Solicitar exclusión
        val intent = Intent().apply {
            action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}
```

## Instrucciones para el Usuario

### Primera vez que abres la app después de actualizar:

1. **Diálogo de Optimización de Batería**: 
   - Aparecerá un diálogo del sistema preguntando si deseas permitir que Z Music ignore las optimizaciones de batería.
   - **Selecciona "Permitir"** o **"Sí"** para obtener la mejor experiencia.

2. **Si no aparece el diálogo o lo cerraste**:
   - Ve a **Configuración** → **Aplicaciones** → **Z Music**
   - Busca **Batería** o **Uso de batería**
   - Selecciona **"Sin restricciones"** o **"No optimizar"**

### Configuración Manual por Fabricante:

#### Samsung (One UI)
1. Configuración → Aplicaciones → Z Music
2. Batería → Permitir uso en segundo plano: **Sin restricciones**
3. Configuración → Cuidado del dispositivo → Batería → Límites de uso en segundo plano
4. Agregar Z Music a **"Apps que no se suspenderán"**

#### Xiaomi (MIUI)
1. Configuración → Aplicaciones → Administrar aplicaciones → Z Music
2. Ahorro de batería: **Sin restricciones**
3. Inicio automático: **Activado**
4. Configuración → Batería → Ahorro de batería → Elegir aplicaciones
5. Z Music: **Sin restricciones**

#### Huawei (EMUI)
1. Configuración → Aplicaciones → Z Music
2. Batería → Inicio de aplicación: **Administración manual**
3. Activar: Inicio automático, Inicio secundario, Ejecutar en segundo plano

#### OnePlus (OxygenOS)
1. Configuración → Aplicaciones → Z Music
2. Batería → Optimización de batería: **No optimizar**

#### Oppo/Realme (ColorOS)
1. Configuración → Batería → Optimización de batería
2. Z Music → **No optimizar**
3. Configuración → Aplicaciones → Z Music → Permisos
4. Inicio automático: **Activado**

## Resultados Esperados

Después de estas mejoras:

✅ La música continuará reproduciéndose incluso después de cerrar la app desde recientes  
✅ El servicio permanecerá activo durante horas sin interrupciones  
✅ La notificación de reproducción permanecerá visible y funcional  
✅ Los controles en la pantalla de bloqueo seguirán funcionando  
✅ El consumo de batería será razonable (solo durante reproducción activa)  

## Notas Importantes

- **Consumo de Batería**: Estas configuraciones pueden aumentar ligeramente el consumo de batería, pero solo durante la reproducción activa.
- **Notificación Persistente**: La notificación de Z Music será más difícil de eliminar accidentalmente.
- **Control del Usuario**: El usuario siempre puede detener la reproducción desde la notificación o la pantalla de bloqueo.

## Pruebas Recomendadas

1. Iniciar reproducción de música
2. Cerrar la app desde recientes
3. Esperar 1-2 horas con la pantalla apagada
4. Verificar que la música siga reproduciéndose
5. Verificar que los controles de la notificación funcionen

## Troubleshooting

### Si la app aún se cierra después de 1 hora:

1. **Verificar optimización de batería**:
   - Asegúrate de que Z Music esté en "Sin restricciones"

2. **Verificar configuración del fabricante**:
   - Algunos fabricantes tienen configuraciones adicionales (ver arriba)

3. **Modo de ahorro de batería**:
   - Desactiva el modo de ahorro de batería extremo del dispositivo

4. **Aplicaciones de limpieza**:
   - Desactiva aplicaciones de limpieza automática que puedan matar Z Music

## Versión
- Implementado: 2026-01-15
- Versión de la app: 1.0.0
