@echo off
:: ===================================================
::  Basera AI Backend Server — Quick Start
::  Double-click this file to start the server
:: ===================================================

echo.
echo  ██████╗  █████╗ ███████╗███████╗██████╗  █████╗
echo  ██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗
echo  ██████╔╝███████║███████╗█████╗  ██████╔╝███████║
echo  ██╔══██╗██╔══██║╚════██║██╔══╝  ██╔══██╗██╔══██║
echo  ██████╔╝██║  ██║███████║███████╗██║  ██║██║  ██║
echo  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
echo.
echo  Basera AI — Smart Glasses Backend Server
echo  ==========================================
echo.

cd /d D:\smart-glasses

:: Check venv exists
if not exist "venv\Scripts\python.exe" (
    echo [ERROR] Virtual environment not found at D:\smart-glasses\venv\
    echo         Please run: python -m venv venv
    pause
    exit /b 1
)

:: Show server IP addresses (so user can enter in Flutter app)
echo [INFO] Your local IP addresses:
ipconfig | findstr /i "IPv4"
echo.
echo [INFO] Use the IPv4 address above in the Flutter app Settings screen.
echo [INFO] Make sure your phone is on the SAME Wi-Fi network as this PC.
echo.
echo [INFO] Starting server on 0.0.0.0:8000 ...
echo [INFO] Loading SmolVLM2 model (~2 GB) — please wait 10-30 seconds...
echo.

:: Start the FastAPI server
venv\Scripts\python.exe -m uvicorn api_server:app --host 0.0.0.0 --port 8000 --log-level info

pause
