# Script para compilar APK de Z Music y abrir el directorio
# Autor: Generado automáticamente
# Fecha: 2026-01-15

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Compilando Z Music APK" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""


# --- Lógica de Incremento de Versión ---
$pubspecPath = Join-Path $PSScriptRoot "pubspec.yaml"
Write-Host "[0/2] Incrementando versión en pubspec.yaml..." -ForegroundColor Yellow

$content = Get-Content $pubspecPath
$newContent = @()
$found = $false
$newVersion = ""

foreach ($line in $content) {
    if ($line -match 'msix_version:\s*(\d+\.\d+\.\d+\.)(\d+)') {
        $prefix = $matches[1]
        $buildNum = [int]$matches[2] + 1
        $newVersion = "$prefix$buildNum"
        $newContent += "  msix_version: $newVersion"
        $found = $true
    } else {
        $newContent += $line
    }
}

if ($found) {
    $newContent | Set-Content $pubspecPath
    Write-Host "✓ Versión actualizada a: $newVersion" -ForegroundColor Green
} else {
    Write-Host "! No se encontró la línea msix_version para incrementar" -ForegroundColor Cyan
}
# ---------------------------------------

# Compilar APK
Write-Host "[1/2] Compilando MSIX (esto puede tardar varios minutos)..." -ForegroundColor Yellow
dart run msix:create
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error al compilar el MSIX" -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host "[2/2] ✓ MSIX compilado exitosamente" -ForegroundColor Green
Write-Host ""

# Ruta del APK generado
$msixPath = "build\windows\x64\runner\Release"
$fullMsixPath = Join-Path $PSScriptRoot $msixPath

# Verificar que el APK existe
if (Test-Path "$fullMsixPath\zmusic.msix") {
    $apkSize = (Get-Item "$fullMsixPath\zmusic.msix").Length / 1MB
    Write-Host "[4/4] ✓ MSIX generado correctamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  COMPILACIÓN EXITOSA" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Ubicación: $fullMsixPath\zmusic.msix" -ForegroundColor White
    Write-Host "Tamaño: $([math]::Round($apkSize, 2)) MB" -ForegroundColor White
    Write-Host ""
    
    # Abrir el directorio
    Write-Host "Abriendo directorio..." -ForegroundColor Yellow
    Start-Process "explorer.exe" -ArgumentList $fullMsixPath
    
    Write-Host ""
    Write-Host "¡Listo! El MSIX está en la carpeta que se acaba de abrir." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[4/4] ✗ No se encontró el MSIX generado" -ForegroundColor Red
    Write-Host "Ruta esperada: $fullMsixPath\zmusic.msix" -ForegroundColor Yellow
}

