# Scripts de Compilación - Z Music

Este directorio contiene scripts automatizados para compilar el APK de Z Music.

## Scripts Disponibles

### 1. `build_apk.bat` (Recomendado para Windows)
Script batch que funciona en cualquier versión de Windows sin configuración adicional.

**Cómo usar:**
1. Haz doble clic en `build_apk.bat`
2. Espera a que termine la compilación
3. El explorador de Windows se abrirá automáticamente con el APK

### 2. `build_apk.ps1` (PowerShell)
Script de PowerShell con mejor formato visual y manejo de errores.

**Cómo usar:**
1. Clic derecho en `build_apk.ps1`
2. Selecciona "Ejecutar con PowerShell"
3. Si aparece un error de política de ejecución, ejecuta esto en PowerShell como administrador:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. Espera a que termine la compilación
5. El explorador de Windows se abrirá automáticamente con el APK

## Proceso de Compilación

Ambos scripts realizan los siguientes pasos:

1. **Limpiar build anterior** (`flutter clean`)
   - Elimina archivos de compilación anteriores
   - Asegura una compilación limpia

2. **Obtener dependencias** (`flutter pub get`)
   - Descarga todas las dependencias necesarias
   - Actualiza los paquetes

3. **Compilar APK** (`flutter build apk --release`)
   - Compila la aplicación en modo release
   - Optimiza el código para producción
   - Genera el APK firmado

4. **Abrir directorio**
   - Abre automáticamente la carpeta donde se generó el APK
   - Muestra información sobre el archivo generado

## Ubicación del APK

El APK compilado se encuentra en:
```
build\app\outputs\flutter-apk\app-release.apk
```

## Tiempo de Compilación

- **Primera compilación**: 3-5 minutos
- **Compilaciones posteriores**: 1-3 minutos

## Solución de Problemas

### Error: "flutter no se reconoce como comando"
- Asegúrate de tener Flutter instalado y agregado al PATH
- Reinicia la terminal o el sistema después de instalar Flutter

### Error de permisos en PowerShell
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Error de compilación
- Verifica que tengas Android SDK instalado
- Ejecuta `flutter doctor` para ver qué falta

### El APK no se genera
- Revisa los mensajes de error en la consola
- Asegúrate de tener espacio suficiente en disco (al menos 2GB)

## Instalación del APK

Una vez compilado:

1. **En el mismo PC**:
   - Conecta tu dispositivo Android por USB
   - Activa "Depuración USB" en el dispositivo
   - Arrastra el APK al dispositivo o usa `adb install app-release.apk`

2. **Transferir a otro dispositivo**:
   - Copia `app-release.apk` a tu teléfono (USB, email, Drive, etc.)
   - En el teléfono, activa "Instalar apps desconocidas" para el navegador/gestor de archivos
   - Toca el APK para instalarlo

## Notas Importantes

⚠️ **Primera instalación después de las mejoras**:
- La app solicitará permisos para ignorar optimizaciones de batería
- **Acepta este permiso** para evitar que la app se cierre en segundo plano

📱 **Configuración recomendada**:
- Lee el archivo `.agent\MEJORAS_SEGUNDO_PLANO.md` para configurar tu dispositivo
- Especialmente importante en dispositivos Xiaomi, Huawei, Samsung, etc.

## Versión
- Última actualización: 2026-01-15
- Incluye mejoras para reproducción en segundo plano
