#!/bin/bash
# Builds Tack.app into ./build. Usage: ./build.sh [--install]  (--install copies to ~/Applications)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
# The default CLT SDK may be newer than the compiler; prefer the 26.x SDK when present.
SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
[[ -d "$SDK" ]] || SDK="$(xcrun --show-sdk-path)"
swiftc -sdk "$SDK" -O -swift-version 5 -parse-as-library -target arm64-apple-macosx14.0 \
  -o build/Tack Sources/Tack/*.swift
APP=build/Tack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/Tack "$APP/Contents/MacOS/Tack"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Tack</string>
  <key>CFBundleDisplayName</key><string>Tack</string>
  <key>CFBundleIdentifier</key><string>io.github.boyanangelov.tack</string>
  <key>CFBundleExecutable</key><string>Tack</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
if [[ "${1:-}" == "--install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/Tack.app
  cp -R "$APP" ~/Applications/
  echo "Installed to ~/Applications/Tack.app"
fi
