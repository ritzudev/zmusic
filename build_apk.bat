@echo off
echo Compilando APK de Z Music...
echo.

cd /d "%~dp0"

flutter build apk --release

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo APK compilado exitosamente!
    echo.
    start "" "build\app\outputs\flutter-apk"
) else (
    echo.
    echo Error: No se pudo generar el APK
)

pause
