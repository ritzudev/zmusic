# Script de Lanzamiento Manual - Z Music
# Compila localmente (más rápido) y ayuda a subir a GitHub.

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   GENERADOR DE LANZAMIENTO MANUAL - Z MUSIC" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
$releaseFolder = Join-Path $PSScriptRoot "releases"

# 1. Incrementar versión
Write-Host "[1/5] Actualizando versiones en pubspec.yaml..." -ForegroundColor Yellow

$content = Get-Content $pubspecPath
$newContent = @()
$version = ""

foreach ($line in $content) {
    if ($line -match '^version:\s*(\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $buildNum = [int]$matches[2] + 1
        $version = "$prefix$buildNum"
        $newContent += "version: $version"
        Write-Host "   - Nueva versión: $version" -ForegroundColor Green
    } 
    elseif ($line -match 'msix_version:\s*(\d+\.\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $buildNum = [int]$matches[2] + 1
        $newContent += "  msix_version: $prefix$buildNum"
    } 
    else {
        $newContent += $line
    }
}
$newContent | Set-Content $pubspecPath

# 2. Limpieza y Compilación Local (Tu PC es más rápido que GitHub)
Write-Host "[2/5] Limpiando y compilando APK..." -ForegroundColor Yellow
$cleanSuccess = $true
try { flutter clean } catch { $cleanSuccess = $false }
if (!$cleanSuccess) {
    Write-Host "! Carpeta bloqueada. Matando procesos de Java..." -ForegroundColor Cyan
    Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue 
    flutter clean
}
flutter pub get
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "Error en build APK" }

Write-Host "[3/5] Compilando MSIX (Windows)..." -ForegroundColor Yellow
dart run msix:create --install-certificate false
if ($LASTEXITCODE -ne 0) { throw "Error en build MSIX" }

# 3. Organizar archivos
Write-Host "[4/5] Organizando archivos..." -ForegroundColor Yellow
if (!(Test-Path $releaseFolder)) { New-Item -ItemType Directory -Path $releaseFolder | Out-Null }
$apkDest = Join-Path $releaseFolder "ZMusic_v$version.apk"
$msixDest = Join-Path $releaseFolder "ZMusic_v$version.msix"
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $apkDest -Force
Copy-Item "build\windows\x64\runner\Release\zmusic.msix" $msixDest -Force

# 4. Git y Tag
Write-Host "[5/5] Subiendo tag a GitHub..." -ForegroundColor Yellow
git add pubspec.yaml
git commit -m "chore: release v$version"
git push origin main
git tag "v$version"
git push origin "v$version"

# 5. Abrir todo para subir manualmente
Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   ¡LISTO PARA SUBIR!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host " 1. Se abrirá la carpeta con los archivos." -ForegroundColor White
Write-Host " 2. Se abrirá GitHub para que arrastres los archivos." -ForegroundColor White
Write-Host "====================================================" -ForegroundColor Green

Start-Process "explorer.exe" -ArgumentList $releaseFolder
Start-Process "https://github.com/ritzudev/zmusic/releases/new?tag=v$version"

Write-Host "¡Pum! Arrastra el APK y el MSIX a la página de GitHub y listo." -ForegroundColor Cyan
