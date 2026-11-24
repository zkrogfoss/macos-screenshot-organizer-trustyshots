#!/bin/sh
set -eu
cd "$(dirname "$0")"
app="dist/TrustyShots.app"
swift build -c release
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Branding/AppIcon.icns "$app/Contents/Resources/"
cp .build/release/TrustyShots "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "Built: $PWD/$app"
