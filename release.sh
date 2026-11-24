#!/bin/sh
# Builds a universal app and zips it for a GitHub release.
set -eu
cd "$(dirname "$0")"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
out="dist/release"
app="$out/TrustyShots.app"
zip="TrustyShots-$version.zip"
rm -rf "$out"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
# Two builds joined with lipo: passing both --arch values at once needs Xcode.
for arch in arm64 x86_64; do
  swift build -c release --triple "$arch-apple-macosx14.0" --scratch-path ".build/$arch"
  cp "$(swift build -c release --triple "$arch-apple-macosx14.0" --scratch-path ".build/$arch" --show-bin-path)/TrustyShots" "$out/$arch"
done
lipo -create "$out/arm64" "$out/x86_64" -output "$app/Contents/MacOS/TrustyShots"
rm "$out/arm64" "$out/x86_64"
# Debug symbols can hold paths of the build machine.
strip -Sx "$app/Contents/MacOS/TrustyShots"
cp Branding/AppIcon.icns "$app/Contents/Resources/"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
(cd "$out" && ditto -c -k --norsrc --keepParent TrustyShots.app "$zip" && shasum -a 256 "$zip" > "$zip.sha256")
echo "Built: $PWD/$out/$zip"
