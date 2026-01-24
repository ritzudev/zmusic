# Script para generar el lanzamiento completo de Z Music (Android y Windows)
# Este script incrementa la versión, compila ambos binarios y los organiza en una carpeta de salida.

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   GENERADOR DE LANZAMIENTO - Z MUSIC" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
$releaseFolder = Join-Path $PSScriptRoot "releases"

# 1. Incrementar versión en pubspec.yaml
Write-Host "[1/5] Actualizando versiones en pubspec.yaml..." -ForegroundColor Yellow

$content = Get-Content $pubspecPath
$newContent = @()
$version = ""

foreach ($line in $content) {
    # Incrementar versión principal (ej: 0.1.0 -> 0.1.1)
    if ($line -match '^version:\s*(\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $buildNum = [int]$matches[2] + 1
        $version = "$prefix$buildNum"
        $newContent += "version: $version"
        Write-Host "   - Nueva versión de la app: $version" -ForegroundColor Green
    } 
    # Incrementar msix_version (ej: 0.1.0.13 -> 0.1.0.14)
    elseif ($line -match 'msix_version:\s*(\d+\.\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $buildNum = [int]$matches[2] + 1
        $newContent += "  msix_version: $prefix$buildNum"
        Write-Host "   - Nueva versión MSIX: $prefix$buildNum" -ForegroundColor Green
    } 
    else {
        $newContent += $line
    }
}

$newContent | Set-Content $pubspecPath

# 2. Limpiar compilaciones anteriores
Write-Host "[2/5] Limpiando archivos temporales..." -ForegroundColor Yellow
$cleanSuccess = $true
try {
    flutter clean
} catch {
    $cleanSuccess = $false
}

if (!$cleanSuccess) {
    Write-Host "! La carpeta build está bloqueada por otro programa." -ForegroundColor Red
    $choice = Read-Host "¿Quieres intentar forzar el cierre de procesos de Java/Dart para desbloquearla? (s/n)"
    if ($choice -eq "s") {
        Write-Host "Cerrando procesos bloqueantes..." -ForegroundColor Yellow
        Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "dart" -Force -ErrorAction SilentlyContinue
        flutter clean
    } else {
        Write-Host "Intentando continuar sin limpiar..." -ForegroundColor Cyan
    }
}
flutter pub get

# 3. Compilar APK (Android)
Write-Host "[3/5] Compilando APK para Android..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "Error al compilar el APK" }

# 4. Compilar MSIX (Windows)
Write-Host "[4/5] Compilando MSIX para Windows..." -ForegroundColor Yellow
dart run msix:create
if ($LASTEXITCODE -ne 0) { throw "Error al compilar el MSIX" }

# 5. Organizar archivos de salida
Write-Host "[5/5] Organizando archivos de lanzamiento..." -ForegroundColor Yellow

if (!(Test-Path $releaseFolder)) {
    New-Item -ItemType Directory -Path $releaseFolder | Out-Null
}

$apkSource = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-release.apk"
$msixSource = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\zmusic.msix"

$apkDest = Join-Path $releaseFolder "ZMusic_v$version.apk"
$msixDest = Join-Path $releaseFolder "ZMusic_v$version.msix"

Copy-Item $apkSource $apkDest -Force
Copy-Item $msixSource $msixDest -Force

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   ¡LANZAMIENTO GENERADO CON ÉXITO!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host " Versión: $version" -ForegroundColor White
Write-Host " APK: $(Split-Path $apkDest -Leaf)" -ForegroundColor White
Write-Host " MSIX: $(Split-Path $msixDest -Leaf)" -ForegroundColor White
Write-Host " Carpeta: $releaseFolder" -ForegroundColor White
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""

# Abrir el directorio de releases
Start-Process "explorer.exe" -ArgumentList $releaseFolder

Write-Host ""
$push = Read-Host "¿Quieres subir este lanzamiento automáticamente a GitHub? (s/n)"
if ($push -eq "s") {
    Write-Host "Subiendo tag v$version a GitHub..." -ForegroundColor Yellow
    git tag "v$version"
    git push origin "v$version"
    Write-Host "¡Pum! GitHub Actions empezará a compilar y crear el release ahora mismo." -ForegroundColor Green
    Write-Host "Puedes verlo en: https://github.com/ritzudev/zmusic/actions" -ForegroundColor Cyan
}
