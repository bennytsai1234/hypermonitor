@echo off
chcp 65001 >nul
echo ╔══════════════════════════════════════════════════════╗
echo ║  Hyperliquid Scraper - Uninstall Windows Service    ║
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

echo Removing Windows Service...
node scripts/uninstall_service.js
if %errorlevel% neq 0 (
    echo [ERROR] Service removal failed.
    pause
    exit /b 1
)

echo.
echo ✅ Done! HyperliquidScraper has been removed from Windows Services.
echo.
pause
