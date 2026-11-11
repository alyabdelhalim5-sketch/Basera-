@echo off
:: ===================================================
::  Install Flutter SDK on Windows (No Admin needed)
::  Installs to D:\flutter\ to avoid C: drive space
:: ===================================================

echo [Basera] Installing Flutter SDK to D:\flutter\
echo.

set FLUTTER_DIR=D:\flutter
set FLUTTER_VERSION=3.27.3

:: Check if already installed
if exist "%FLUTTER_DIR%\bin\flutter.bat" (
    echo [INFO] Flutter already installed at %FLUTTER_DIR%
    echo [INFO] Version:
    "%FLUTTER_DIR%\bin\flutter.bat" --version
    goto :done
)

:: Download Flutter
echo [STEP 1] Downloading Flutter %FLUTTER_VERSION%...
set FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_%FLUTTER_VERSION%-stable.zip
set FLUTTER_ZIP=%TEMP%\flutter_stable.zip

powershell -Command "Invoke-WebRequest -Uri '%FLUTTER_URL%' -OutFile '%FLUTTER_ZIP%' -UseBasicParsing"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Download failed. Check your internet connection.
    pause
    exit /b 1
)

:: Extract
echo [STEP 2] Extracting to D:\...
powershell -Command "Expand-Archive -Path '%FLUTTER_ZIP%' -DestinationPath 'D:\' -Force"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Extraction failed.
    pause
    exit /b 1
)

del "%FLUTTER_ZIP%"

:: Add to PATH for this session
set PATH=%FLUTTER_DIR%\bin;%PATH%

:done
echo.
echo [STEP 3] Adding Flutter to your user PATH permanently...
powershell -Command "[Environment]::SetEnvironmentVariable('PATH', $env:PATH + ';D:\flutter\bin', [EnvironmentVariableTarget]::User)"

echo.
echo [STEP 4] Running flutter doctor...
"%FLUTTER_DIR%\bin\flutter.bat" doctor

echo.
echo ================================================================
echo  Flutter installed! Now run:
echo    setup_flutter_project.bat
echo ================================================================
echo.
pause
