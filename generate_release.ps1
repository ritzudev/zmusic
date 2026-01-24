# Script de Lanzamiento Atómico - Z Music
# Sincroniza: Features + Incremento de Versión + Build + Tag + Push

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   GENERADOR DE LANZAMIENTO ATÓMICO - Z MUSIC" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si hay cambios pendientes
$status = git status --porcelain
if (-not $status) {
    Write-Host "! No hay cambios detectados. ¿Seguro que quieres lanzar una nueva versión sin cambios?" -ForegroundColor Yellow
    $ans = Read-Host "(s/n)"
    if ($ans -ne "s") { exit }
}

# 1. Preguntar por los cambios (para el mensaje de commit)
$changeLog = Read-Host "🎨 ¿Qué novedades tiene esta versión? (Ej: Arreglado bug de rumbita)"
if (-not $changeLog) { $changeLog = "Mejoras generales y correcciones" }

$pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
$releaseFolder = Join-Path $PSScriptRoot "releases"

# 2. Incrementar versión en pubspec.yaml antes de nada
Write-Host "[1/6] Incrementando versiones..." -ForegroundColor Yellow
$content = Get-Content $pubspecPath
$newContent = @()
$version = ""

foreach ($line in $content) {
    if ($line -match '^version:\s*(\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $buildNum = [int]$matches[2] + 1
        $version = "$prefix$buildNum"
        $newContent += "version: $version"
    } 
    elseif ($line -match 'msix_version:\s*(\d+\.\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $buildNum = [int]$matches[2] + 1
        $newContent += "  msix_version: $prefix$buildNum"
    } 
    else { $newContent += $line }
}
$newContent | Set-Content $pubspecPath
Write-Host "   ✓ Versión preparada: $version" -ForegroundColor Green

# 3. Guardar TODO en Git (Features + Versión)
Write-Host "[2/6] Guardando todos los cambios en Git..." -ForegroundColor Yellow
git add .
git commit -m "feat: $changeLog (v$version)"
Write-Host "   ✓ Commit creado con éxito." -ForegroundColor Green

# 4. Compilación Local con la nueva versión
Write-Host "[3/6] Compilando APK (Android)..." -ForegroundColor Yellow
$cleanSuccess = $true
try { flutter clean } catch { $cleanSuccess = $false }
if (!$cleanSuccess) {
    Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue 
    flutter clean
}
flutter pub get
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "Error en build APK" }

Write-Host "[4/6] Compilando MSIX (Windows)..." -ForegroundColor Yellow
dart run msix:create --install-certificate false
if ($LASTEXITCODE -ne 0) { throw "Error en build MSIX" }

# 5. Organizar archivos
Write-Host "[5/6] Organizando archivos..." -ForegroundColor Yellow
if (!(Test-Path $releaseFolder)) { New-Item -ItemType Directory -Path $releaseFolder | Out-Null }
$apkDest = Join-Path $releaseFolder "ZMusic_v$version.apk"
$msixDest = Join-Path $releaseFolder "ZMusic_v$version.msix"
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $apkDest -Force
Copy-Item "build\windows\x64\runner\Release\zmusic.msix" $msixDest -Force

# 6. Tag y Push Final
Write-Host "[6/6] Sincronizando con GitHub..." -ForegroundColor Yellow
git tag "v$version"
git push origin main
git push origin "v$version"

# 7. GitHub Release Atómico
Write-Host "[7/7] Creando lanzamiento oficial en GitHub..." -ForegroundColor Yellow
gh release create "v$version" $apkDest $msixDest --title "v$version" --notes "feat: $changeLog"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   ¡LANZAMIENTO v$version PUBLICADO!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""

Start-Process "explorer.exe" -ArgumentList $releaseFolder
Write-Host "¡Pum! Todo listo. Los archivos ya están en la nube." -ForegroundColor Cyan
