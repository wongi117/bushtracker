@echo off
echo.
echo ==== BushTrack Netlify Deploy Script ====
echo.

REM Build Flutter web
echo Building Flutter web...
cd /d "%~dp0bush_track"
flutter build web --release
if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

REM Create zip
echo Creating zip...
powershell -NoProfile -Command "Compress-Archive -Path 'buildweb*' -DestinationPath 'deploy.zip' -Force"

REM Show zip location
echo.
echo ========================================
echo.
echo ZIP created: %~dp0bush_track\deploy.zip
echo.
echo TO DEPLOY:
echo 1. Go to https://netlify.com/drag-and-drop
echo 2. Drag the deploy.zip file
echo.
pause