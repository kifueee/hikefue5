#!/bin/bash

echo "🚀 Deploying hikefue5 to DigitalOcean App Platform"
echo "=================================================="

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build for web
echo "🌐 Building Flutter web app..."
flutter build web --web-renderer html --release

# Check if build was successful
if [ -d "build/web" ]; then
    echo "✅ Build successful! Files created in build/web/"
    echo "📊 Build size:"
    du -sh build/web
    echo ""
    echo "📁 Main files:"
    ls -la build/web/
    echo ""
    echo "🔗 You can test locally by running:"
    echo "   cd build/web && python -m http.server 8080"
    echo "   Then visit: http://localhost:8080"
    echo ""
    echo "🚀 Ready for DigitalOcean App Platform deployment!"
else
    echo "❌ Build failed! Check the error messages above."
    exit 1
fi