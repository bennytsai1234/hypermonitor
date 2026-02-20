@echo off
title Hyperliquid Headless Scraper
color 0A

echo ===================================================
echo     Hyperliquid Headless Scraper Auto-Start
echo ===================================================
echo.

REM 取得當前批次檔的路徑，然後切換回專案根目錄 (即 Floder\Hyperliquid)
cd /d "%~dp0\..\.."

echo [INFO] 工作目錄: %CD%
echo.

REM 檢查是否安裝了 Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] 找不到 Node.js！請先下載並安裝 Node.js: https://nodejs.org/
    pause
    exit /b 1
)

REM 取得 Node 版本
for /f "tokens=*" %%v in ('node -v') do set NODE_VER=%%v
echo [INFO] Node.js 版本: %NODE_VER%

REM 檢查是否缺少 node_modules，如果缺少則自動安裝 npm install
if not exist "node_modules\puppeteer" (
    echo.
    echo [WARN] 尚未安裝依賴套件 (node_modules/puppeteer 遺失)。
    echo [INFO] 正在自動執行 npm install...
    call npm install
    if %errorlevel% neq 0 (
        color 0C
        echo.
        echo [ERROR] npm install 安裝失敗！請檢查網路或權限。
        pause
        exit /b 1
    )
    echo [SUCCESS] 套件安裝完成！
    echo.
) else (
    echo [INFO] 依賴套件已安裝。
)

echo.
echo [INFO] 正在啟動 Headless Scraper...
echo ===================================================
echo.

REM 啟動爬蟲
node scripts\headless_scraper.js

if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] 爬蟲發生異常並退出。(Error Code: %errorlevel%)
    pause
    exit /b %errorlevel%
)

pause
