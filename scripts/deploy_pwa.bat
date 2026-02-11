@echo off
echo [DEPLOY] Starting deployment to Cloudflare Pages...
echo.

cd /d "%~dp0\.."
echo [INFO] Current directory: %CD%

REM Check if wrangler is installed
call npx wrangler --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Wrangler not found. Installing...
    call npm install -g wrangler
)

echo [INFO] Deploying 'pwa' folder...
call npx wrangler pages deploy pwa --project-name=hyper-monitor --branch=main

echo.
echo [SUCCESS] Deployment complete!
echo [INFO] Your PWA should be live at: https://hyper-monitor.pages.dev
echo.
timeout /t 10
