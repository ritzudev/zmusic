# Scripts de Compilación - Z Music

Este directorio contiene scripts automatizados para compilar Z Music para Android y Windows.

## Scripts Disponibles

### 1. `generate_release.ps1` (Lanzamiento Completo)
**¡Recomendado!** Este script es el más completo:
1. Incrementa automáticamente la versión en `pubspec.yaml`.
2. Compila el APK para Android.
3. Compila el MSIX para Windows.
4. Organiza ambos archivos en una carpeta llamada `releases` con nombres claros (ej: `ZMusic_v0.1.1.apk`).

**Cómo usar:**
1. Clic derecho en `generate_release.ps1`
2. Selecciona "Ejecutar con PowerShell"
3. Espera a que termine y se abrirá la carpeta con tus archivos listos para subir a GitHub.

### 2. `build_apk.ps1` (Solo Android)
Script de PowerShell para compilar solo el APK.

**Cómo usar:**
1. Clic derecho en `build_apk.ps1`
2. Selecciona "Ejecutar con PowerShell"

### 3. `msix_app.ps1` (Solo Windows)
Script para compilar solo el instalador de Windows.

**Cómo usar:**
1. Clic derecho en `msix_app.ps1`
2. Selecciona "Ejecutar con PowerShell"

---

## Proceso de Compilación (Manual)

Si prefieres hacerlo a mano, los pasos son:

1. **Limpiar**: `flutter clean`
2. **Obtener paquetes**: `flutter pub get`
3. **Android**: `flutter build apk --release`
4. **Windows**: `dart run msix:create`

## Ubicación de los Archivos

- **APK**: `build\app\outputs\flutter-apk\app-release.apk`
- **MSIX**: `build\windows\x64\runner\Release\zmusic.msix`
- **Lanzamientos organizados**: Carpeta `releases/` (después de usar `generate_release.ps1`)

## Solución de Problemas

### Error de permisos en PowerShell
Si Windows bloquea los scripts, ejecuta esto como administrador en PowerShell:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Versión de MSIX
La versión de Windows se controla en el `pubspec.yaml` bajo la sección `msix_config`. El script `generate_release.ps1` se encarga de que coincida con la versión de la app.

---
Última actualización: 2026-01-24
Incluye soporte para Auto-Update y generación de builds duales.
