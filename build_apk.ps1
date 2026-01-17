# Script para compilar APK de Z Music y abrir el directorio
# Autor: Generado automáticamente
# Fecha: 2026-01-15

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Compilando Z Music APK" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""


# Compilar APK
Write-Host "[1/2] Compilando APK (esto puede tardar varios minutos)..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al compilar el APK" -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host "[2/2] ✓ APK compilado exitosamente" -ForegroundColor Green
Write-Host ""

# Ruta del APK generado
$apkPath = "build\app\outputs\flutter-apk"
$fullApkPath = Join-Path $PSScriptRoot $apkPath

# Verificar que el APK existe
if (Test-Path "$fullApkPath\app-release.apk") {
    $apkSize = (Get-Item "$fullApkPath\app-release.apk").Length / 1MB
    Write-Host "[4/4] ✓ APK generado correctamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  COMPILACIÓN EXITOSA" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ubicación: $fullApkPath\app-release.apk" -ForegroundColor White
    Write-Host "Tamaño: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
    Write-Host ""
    
    # Abrir el directorio
    Write-Host "Abriendo directorio..." -ForegroundColor Yellow
    Start-Process "explorer.exe" -ArgumentList $fullApkPath
    
    Write-Host ""
    Write-Host "¡Listo! El APK está en la carpeta que se acaba de abrir." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[4/4] ✗ No se encontró el APK generado" -ForegroundColor Red
    Write-Host "Ruta esperada: $fullApkPath\app-release.apk" -ForegroundColor Yellow
}

