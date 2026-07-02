#!/bin/bash
# Build Clotch.app from the SwiftPM ClotchApp executable and install the clotch CLI.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/Clotch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/ClotchApp "$APP/Contents/MacOS/Clotch"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Clotch</string>
    <key>CFBundleIdentifier</key>
    <string>dev.mark.clotch</string>
    <key>CFBundleName</key>
    <string>Clotch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"

echo "Built $APP"
echo
echo "Install CLI:  cp .build/release/clotch /usr/local/bin/  (or anywhere on PATH)"
echo "Run app:      open $APP"
