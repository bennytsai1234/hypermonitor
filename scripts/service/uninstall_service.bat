@echo off
setlocal
chcp 65001 >nul

echo =========================================================
echo   Hyperliquid Scraper - Windows Service Uninstaller
echo   Requires Administrator Privileges
echo =========================================================
echo.

:: 1. Auto-elevate to Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c, \"%~f0\"' -Verb RunAs"
    exit /b
)

:: 2. Set strict working directory (Root of project)
set "PROJECT_ROOT=%~dp0..\.."
cd /d "%PROJECT_ROOT%"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to navigate to project root: %PROJECT_ROOT%
    pause
    exit /b 1
)

:: 3. Remove the Service
echo [1/1] Removing the Windows Service...
node scripts/service/uninstall_service.js
if %errorlevel% neq 0 (
    echo [ERROR] Service removal failed. See logs above.
    pause
    exit /b 1
)

echo.
echo =========================================================
echo   [SUCCESS] HyperliquidScraper has been removed!
echo =========================================================
echo.
pause
