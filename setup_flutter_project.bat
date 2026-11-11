@echo off
:: ===================================================
::  Basera Flutter App — Setup Script
::  Run this ONCE to initialize the Flutter project
:: ===================================================

echo [Basera] Flutter Project Setup
echo ================================
echo.

:: ── 1. Check Flutter ─────────────────────────────────────────────────────────
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [STEP 1] Flutter not found in PATH.
    echo.
    echo   Please install Flutter from: https://docs.flutter.dev/get-started/install/windows
    echo   Then add it to PATH and re-run this script.
    echo.
    echo   Quick install steps:
    echo   1. Download flutter_windows_stable.zip from flutter.dev
    echo   2. Extract to C:\src\flutter
    echo   3. Add C:\src\flutter\bin to your PATH
    echo   4. Run: flutter doctor
    echo   5. Re-run this script
    pause
    exit /b 1
)

echo [STEP 1] Flutter found: 
flutter --version
echo.

:: ── 2. Check if project already initialized ───────────────────────────────────
if exist "D:\smart-glasses\basera_flutter\.dart_tool" (
    echo [STEP 2] Project already initialized. Skipping flutter create.
) else (
    echo [STEP 2] Initializing Flutter project structure...
    :: The lib/ code is already written. We just need flutter to generate
    :: the native wrappers. Use --empty to avoid overwriting our lib/ files.
    cd /d D:\smart-glasses
    flutter create --org com.basera --project-name basera_flutter --platforms android,ios --empty basera_flutter_tmp
    
    :: Copy generated native files, don't overwrite our dart files
    if exist basera_flutter_tmp (
        xcopy /E /Y /I basera_flutter_tmp\android basera_flutter\android
        xcopy /E /Y /I basera_flutter_tmp\ios basera_flutter\ios
        xcopy /E /Y /I basera_flutter_tmp\.dart_tool basera_flutter\.dart_tool
        copy /Y basera_flutter_tmp\pubspec.lock basera_flutter\pubspec.lock 2>nul
        copy /Y basera_flutter_tmp\analysis_options.yaml basera_flutter\analysis_options.yaml 2>nul
        rmdir /S /Q basera_flutter_tmp
    )
)
echo.

:: ── 3. Install dependencies ───────────────────────────────────────────────────
echo [STEP 3] Installing Flutter packages...
cd /d D:\smart-glasses\basera_flutter
flutter pub get
echo.

:: ── 4. flutter doctor ────────────────────────────────────────────────────────
echo [STEP 4] Running flutter doctor...
flutter doctor
echo.

echo ================================================================
echo  SETUP COMPLETE
echo ================================================================
echo.
echo  To build and install on Android:
echo    1. Enable USB Debugging on your phone
echo    2. Connect via USB cable
echo    3. Run: cd D:\smart-glasses\basera_flutter
echo            flutter run
echo.
echo  Or build an APK:
echo    flutter build apk --release
echo    APK will be at: build\app\outputs\flutter-apk\app-release.apk
echo.
echo  Don't forget to start the backend server first!
echo    Double-click: D:\smart-glasses\start_server.bat
echo.
pause
