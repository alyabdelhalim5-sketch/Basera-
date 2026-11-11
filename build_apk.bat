@echo off
:: ===================================================
::  Build Basera Flutter APK (Release)
::  Run after: setup_flutter_project.bat
:: ===================================================

echo [Basera] Building Release APK...
echo.

cd /d D:\smart-glasses\basera_flutter

:: Clean previous build
flutter clean

:: Get dependencies
flutter pub get

:: Build APK
flutter build apk --release

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Build failed. Check errors above.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  BUILD SUCCESSFUL!
echo ============================================================
echo.
echo  APK location:
echo  D:\smart-glasses\basera_flutter\build\app\outputs\flutter-apk\app-release.apk
echo.
echo  To install on your phone:
echo    Option 1: flutter install
echo    Option 2: Copy APK to phone, enable "Install from unknown sources"
echo              and install manually.
echo.
echo  Or use: flutter run  (requires USB debugging enabled)
echo.
pause
