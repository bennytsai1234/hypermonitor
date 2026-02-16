@echo off
echo [DEPLOY] Starting deployment of PWA2 (Analysis Version) to Cloudflare Pages...
echo.

cd /d "%~dp0\.."
echo [INFO] Current directory: %CD%

REM Check if wrangler is installed
call npx wrangler --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Wrangler not found. Installing...
    call npm install -g wrangler
)

echo [INFO] Deploying 'pwa2' folder...
REM Using a new project name 'hyper-monitor-pwa2' to keep it separate from the main app
call npx wrangler pages deploy pwa2 --project-name=hyper-monitor-pwa2 --branch=main

echo.
echo [SUCCESS] PWA2 Deployment complete!
echo [INFO] Your Analysis App should be live at: https://hyper-monitor-pwa2.pages.dev
echo.
timeout /t 10
