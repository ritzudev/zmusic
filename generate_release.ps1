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

# 4. Selección de plataforma
Write-Host "🚀 ¿Qué quieres compilar?" -ForegroundColor Cyan
Write-Host "1. Solo Android (APK)"
Write-Host "2. Solo Windows (MSIX)"
Write-Host "3. Ambos (Recomendado para Release final)"
$choice = Read-Host "Elige una opción (1-3)"

$buildAndroid = ($choice -eq "1" -or $choice -eq "3")
$buildWindows = ($choice -eq "2" -or $choice -eq "3")

# 5. Compilación Local
if ($buildAndroid) {
    Write-Host "[3/6] Compilando APK (Android)..." -ForegroundColor Yellow
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw "Error en build APK" }
}

if ($buildWindows) {
    Write-Host "[4/6] Compilando MSIX (Windows)..." -ForegroundColor Yellow
    dart run msix:create --install-certificate false
    if ($LASTEXITCODE -ne 0) { throw "Error en build MSIX" }
}

# 6. Organizar archivos
Write-Host "[5/6] Organizando archivos..." -ForegroundColor Yellow
if (!(Test-Path $releaseFolder)) { New-Item -ItemType Directory -Path $releaseFolder | Out-Null }

$assetsToUpload = @()
$apkDest = Join-Path $releaseFolder "ZMusic_v$version.apk"
$msixDest = Join-Path $releaseFolder "ZMusic_v$version.msix"

if ($buildAndroid) {
    Write-Host "   -> Moviendo nuevo APK..." -ForegroundColor Gray
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $apkDest -Force
    $assetsToUpload += $apkDest
}

if ($buildWindows) {
    Write-Host "   -> Moviendo nuevo MSIX..." -ForegroundColor Gray
    Copy-Item "build\windows\x64\runner\Release\zmusic.msix" $msixDest -Force
    $assetsToUpload += $msixDest
} else {
    # TRUCO: Si no compilamos Windows, buscamos el MSIX más reciente de la carpeta para no dejar el release vacío
    $latestMsix = Get-ChildItem -Path $releaseFolder -Filter "*.msix" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestMsix) {
        Write-Host "   -> Reutilizando MSIX anterior ($($latestMsix.Name)) para ahorrar tiempo..." -ForegroundColor Gray
        Copy-Item $latestMsix.FullName $msixDest -Force
        $assetsToUpload += $msixDest
    }
}

# 6. Tag y Push Final
Write-Host "[6/6] Sincronizando con GitHub..." -ForegroundColor Yellow
git tag "v$version"
git push origin main
git push origin "v$version"

# 7. GitHub Release Atómico
Write-Host "[7/7] Creando lanzamiento oficial en GitHub..." -ForegroundColor Yellow
gh release create "v$version" $assetsToUpload --title "v$version" --notes "feat: $changeLog"

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   ¡LANZAMIENTO v$version PUBLICADO!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""

Start-Process "explorer.exe" -ArgumentList $releaseFolder
Write-Host "¡Pum! Todo listo. Los archivos ya están en la nube." -ForegroundColor Cyan
