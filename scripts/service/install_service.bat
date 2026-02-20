@echo off
setlocal
chcp 65001 >nul

echo =========================================================
echo   Hyperliquid Scraper - Windows Service Installer
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

:: 3. Install dependencies quietly (only show errors)
echo [1/2] Installing dependencies (node-windows)...
call npm install node-windows --silent
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install dependencies. Please check if Node.js/npm is installed.
    pause
    exit /b 1
)

:: 4. Register the Service
echo.
echo [2/2] Registering and starting the service...
node scripts/service/install_service.js
if %errorlevel% neq 0 (
    echo [ERROR] Service installation failed. See logs above.
    pause
    exit /b 1
)

echo.
echo =========================================================
echo   [SUCCESS] The service has been installed and started!
echo   You can verify it by opening 'services.msc'
echo   and looking for 'HyperliquidScraper'.
echo =========================================================
echo.
pause
