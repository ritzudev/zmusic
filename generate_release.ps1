# Script de Lanzamiento Atómico - Z Music
# Sincroniza: Incremento de Versión + Build + Commit + Tag + Push + GitHub Release

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   GENERADOR DE LANZAMIENTO ATÓMICO - Z MUSIC" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si GitHub CLI está disponible y autenticado
try {
    $null = gh auth status 2>&1
} catch {
    Write-Warning "GitHub CLI (gh) no está autenticado o no está instalado. Asegúrate de tener 'gh auth login' listo."
}

# 1. Preguntar por los cambios (para el mensaje de commit y release notes)
$changeLog = Read-Host "🎨 ¿Qué novedades tiene esta versión? (Ej: Arreglado bug de rumbita)"
if (-not $changeLog) { $changeLog = "Mejoras generales y correcciones" }

# 2. Selección de plataforma
Write-Host ""
Write-Host "🚀 ¿Qué quieres compilar?" -ForegroundColor Cyan
Write-Host "1. Solo Android (APK)"
Write-Host "2. Solo Windows (MSIX)"
Write-Host "3. Ambos (Recomendado para Release final)"
$choice = Read-Host "Elige una opción (1-3)"

$buildAndroid = ($choice -eq "1" -or $choice -eq "3")
$buildWindows = ($choice -eq "2" -or $choice -eq "3")

if (-not $buildAndroid -and -not $buildWindows) {
    Write-Host "Opción inválida. Cancelando lanzamiento." -ForegroundColor Red
    exit 1
}

$pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
$releaseFolder = Join-Path $PSScriptRoot "releases"
$pubspecBackup = Get-Content $pubspecPath

# 3. Incrementar versión en pubspec.yaml
Write-Host ""
Write-Host "[1/6] Incrementando versión en pubspec.yaml..." -ForegroundColor Yellow
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

if (-not $version) {
    Write-Host "No se pudo detectar la versión en pubspec.yaml." -ForegroundColor Red
    exit 1
}

$newContent | Set-Content $pubspecPath
Write-Host "   ✓ Versión calculada: v$version" -ForegroundColor Green

# 4. Compilación Local (Antes de hacer commit para no registrar versiones rotas)
try {
    if ($buildAndroid) {
        Write-Host ""
        Write-Host "[2/6] Compilando APK (Android Release)..." -ForegroundColor Yellow
        flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw "Error al compilar APK" }
        Write-Host "   ✓ APK compilado con éxito." -ForegroundColor Green
    }

    if ($buildWindows) {
        Write-Host ""
        Write-Host "[3/6] Compilando MSIX (Windows Release)..." -ForegroundColor Yellow
        dart run msix:create --install-certificate false
        if ($LASTEXITCODE -ne 0) { throw "Error al compilar MSIX" }
        Write-Host "   ✓ MSIX compilado con éxito." -ForegroundColor Green
    }
} catch {
    Write-Host ""
    Write-Host "❌ Error durante la compilación: $_" -ForegroundColor Red
    Write-Host "Restaurando versión previa en pubspec.yaml..." -ForegroundColor Yellow
    $pubspecBackup | Set-Content $pubspecPath
    exit 1
}

# 5. Organizar archivos en releases/
Write-Host ""
Write-Host "[4/6] Organizando archivos para distribución..." -ForegroundColor Yellow
if (!(Test-Path $releaseFolder)) { New-Item -ItemType Directory -Path $releaseFolder | Out-Null }

$assetsToUpload = @()
$apkDest = Join-Path $releaseFolder "ZMusic_v$version.apk"
$msixDest = Join-Path $releaseFolder "ZMusic_v$version.msix"

if ($buildAndroid) {
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" $apkDest -Force
    $assetsToUpload += $apkDest
    Write-Host "   -> APK preparado: ZMusic_v$version.apk" -ForegroundColor Gray
}

if ($buildWindows) {
    Copy-Item "build\windows\x64\runner\Release\zmusic.msix" $msixDest -Force
    $assetsToUpload += $msixDest
    Write-Host "   -> MSIX preparado: ZMusic_v$version.msix" -ForegroundColor Gray
} else {
    # Si no se compiló Windows, reutilizar el último MSIX si existe
    $latestMsix = Get-ChildItem -Path $releaseFolder -Filter "*.msix" | Where-Object { $_.FullName -ne $msixDest } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestMsix) {
        Write-Host "   -> Reutilizando MSIX previo ($($latestMsix.Name)) para Windows..." -ForegroundColor Gray
        Copy-Item $latestMsix.FullName $msixDest -Force
        $assetsToUpload += $msixDest
    }
}

# 6. Commit y Push a Git
Write-Host ""
Write-Host "[5/6] Guardando cambios y sincronizando rama principal..." -ForegroundColor Yellow
git add .
git commit -m "feat: $changeLog (v$version)"
git push origin main

# 7. GitHub Release y subida de ejecutables
Write-Host ""
Write-Host "[6/6] Publicando Release v$version en GitHub con binarios..." -ForegroundColor Yellow

$releaseSuccess = $false
try {
    # Intenta crear la release directamente (gh creará el tag automáticamente si no existe)
    & gh release create "v$version" $assetsToUpload --title "v$version" --notes "feat: $changeLog"
    if ($LASTEXITCODE -eq 0) { $releaseSuccess = $true }
} catch {
    $releaseSuccess = $false
}

# Si ya existía el tag/release o falló la creación directa, actualizar notas y subir assets
if (-not $releaseSuccess) {
    Write-Host "   -> Actualizando release existente en GitHub..." -ForegroundColor Cyan
    & gh release edit "v$version" --title "v$version" --notes "feat: $changeLog"
    & gh release upload "v$version" $assetsToUpload --clobber
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   ¡LANZAMIENTO v$version PUBLICADO CON ÉXITO!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Notas: feat: $changeLog" -ForegroundColor Gray
Write-Host "Archivos subidos: $(($assetsToUpload | ForEach-Object { Split-Path $_ -Leaf }) -join ', ')" -ForegroundColor Gray
Write-Host ""

Start-Process "explorer.exe" -ArgumentList $releaseFolder
