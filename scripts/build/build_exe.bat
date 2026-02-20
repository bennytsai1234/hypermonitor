@echo off
chcp 65001 >nul
echo ╔══════════════════════════════════════════╗
echo ║  Hyperliquid Scraper - Build .EXE       ║
echo ╚══════════════════════════════════════════╝
echo.

cd /d "%~dp0.."

echo [1/3] Installing dependencies...
call npm install
if %errorlevel% neq 0 (
    echo [ERROR] npm install failed. Aborting.
    pause
    exit /b 1
)

echo.
echo [2/3] Installing pkg globally (if not installed)...
call npm install -g pkg 2>nul
if %errorlevel% neq 0 (
    echo [WARN] Could not install pkg globally, trying local...
)

echo.
echo [3/3] Packaging into .exe...
if not exist dist mkdir dist
call npx pkg . --targets node18-win-x64 --out-path dist
if %errorlevel% neq 0 (
    echo [ERROR] pkg build failed.
    pause
    exit /b 1
)

echo.
echo ✅ Build complete! Output:
dir dist\*.exe
echo.
echo Usage: dist\hyperliquid-scraper.exe
echo   Set CHROME_PATH env var to override Chrome location.
echo.
pause
