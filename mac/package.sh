#!/bin/bash
# Build "build/Jev Assistant.app": a menu-bar app, ad-hoc signed.
# Ad-hoc signatures change every build, so macOS may ask for Accessibility again after a rebuild.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --product JevMac
APP="build/Jev Assistant.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/JevMac "$APP/Contents/MacOS/JevMac"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.jev.assistant.mac</string>
  <key>CFBundleName</key><string>Jev Assistant</string>
  <key>CFBundleExecutable</key><string>JevMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.4</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "built $APP"
