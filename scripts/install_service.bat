@echo off
chcp 65001 >nul
echo ╔══════════════════════════════════════════════════════╗
echo ║  Hyperliquid Scraper - Install Windows Service      ║
echo ║  ⚠️  REQUIRES ADMINISTRATOR PRIVILEGES              ║
echo ╚══════════════════════════════════════════════════════╝
echo.

:: Auto-elevate to Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c, \"%~f0\"' -Verb RunAs"
    exit /b
)

cd /d "%~dp0.."

echo [1/2] Installing node-windows dependency...
call npm install node-windows
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install node-windows. Aborting.
    pause
    exit /b 1
)

echo.
echo [2/2] Registering Windows Service...
node scripts/install_service.js
if %errorlevel% neq 0 (
    echo [ERROR] Service installation failed.
    pause
    exit /b 1
)

echo.
echo ✅ Done! Open services.msc to verify the HyperliquidScraper service.
echo.
pause
