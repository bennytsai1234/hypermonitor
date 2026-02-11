@echo off
cd /d "%~dp0\.."
echo [INFO] Starting Android APK Build...
echo [INFO] Ensuring dependencies...
call flutter pub get

echo [INFO] Building Release APK...
call flutter build apk --release

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed! Please check the logs above.
    pause
    exit /b %ERRORLEVEL%
)

echo [SUCCESS] APK built successfully!
echo [INFO] You can find the APK at: build\app\outputs\flutter-apk\app-release.apk
echo.
echo [INSTRUCTION]
echo 1. Connect your Android phone to PC via USB.
echo 2. Run: flutter install
echo    OR copy the APK file to your phone and install it manually.
echo.
timeout /t 15
