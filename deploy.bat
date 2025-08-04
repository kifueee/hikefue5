@echo off
echo 🚀 Deploying hikefue5 to DigitalOcean App Platform
echo ==================================================

:: Clean previous builds
echo 🧹 Cleaning previous builds...
flutter clean

:: Get dependencies
echo 📦 Getting dependencies...
flutter pub get

:: Build for web
echo 🌐 Building Flutter web app...
flutter build web --web-renderer html --release

:: Check if build was successful
if exist "build\web" (
    echo ✅ Build successful! Files created in build\web\
    echo 📊 Build size:
    dir build\web /s
    echo.
    echo 🔗 You can test locally by running:
    echo    cd build\web ^&^& python -m http.server 8080
    echo    Then visit: http://localhost:8080
    echo.
    echo 🚀 Ready for DigitalOcean App Platform deployment!
) else (
    echo ❌ Build failed! Check the error messages above.
    pause
    exit /b 1
)

pause