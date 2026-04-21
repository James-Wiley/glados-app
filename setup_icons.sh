#!/bin/bash
# Setup Flutter launcher icons and splash screens

echo "📱 Setting up Flutter app icon and splash screen..."
echo ""

# Generate launcher icons
echo "🎨 Generating app icons..."
flutter pub get
dart run flutter_launcher_icons

# Generate splash screen
echo "🌅 Generating splash screen..."
dart run flutter_native_splash:create

echo ""
echo "✅ Done! Icons and splash screen have been generated for all platforms."
echo ""
echo "To customize further:"
echo "  - Edit assets/images/app_icon.svg for the app icon"
echo "  - Edit assets/images/splash_screen.svg for the splash screen"
echo "  - Then re-run this script or run the commands above"
