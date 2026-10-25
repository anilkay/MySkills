#!/usr/bin/env bash
# Wraps a macOS publish of the app into "<APP_NAME>.app", so it opens with a double click, has the
# app icon and shows the permission texts from Info.plist. Runs on macOS (plutil, iconutil, codesign,
# and rsvg-convert from "brew install librsvg").
#
#   bash <this script> <publish folder> <version> <output folder>
#
# The bundle is signed ad hoc (no Apple Developer account): Apple Silicon needs a signature to run
# at all. It is not notarized, so a downloaded copy has to be allowed once (see the README).
set -euo pipefail

APP_NAME="My App"                 # the .app name and what Finder shows
EXECUTABLE="MyApp"                # the apphost: the project's AssemblyName
here=$(cd "$(dirname "$0")" && pwd)
ICON_PNGS="$here/../../../assets/logo/png"   # 16.png 32.png 64.png 128.png 256.png
ICON_SVG="$here/../../../assets/logo/logo.svg"

publish=$1
version=$2
out=$3
app="$out/$APP_NAME.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -R "$publish/." "$app/Contents/MacOS/"

cp "$here/Info.plist" "$app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$version" "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist"

# The icon: up to 256 px from the PNGs (small sizes are often drawn by hand), larger from the SVG.
iconset=$(mktemp -d)/AppIcon.iconset
mkdir -p "$iconset"
cp "$ICON_PNGS/16.png" "$iconset/icon_16x16.png"
cp "$ICON_PNGS/32.png" "$iconset/icon_16x16@2x.png"
cp "$ICON_PNGS/32.png" "$iconset/icon_32x32.png"
cp "$ICON_PNGS/64.png" "$iconset/icon_32x32@2x.png"
cp "$ICON_PNGS/128.png" "$iconset/icon_128x128.png"
cp "$ICON_PNGS/256.png" "$iconset/icon_128x128@2x.png"
cp "$ICON_PNGS/256.png" "$iconset/icon_256x256.png"
rsvg-convert -w 512 -h 512 -o "$iconset/icon_256x256@2x.png" "$ICON_SVG"
cp "$iconset/icon_256x256@2x.png" "$iconset/icon_512x512.png"
rsvg-convert -w 1024 -h 1024 -o "$iconset/icon_512x512@2x.png" "$ICON_SVG"
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

# macOS treats every file in Contents/MacOS as code, the .NET assemblies too, so each one is signed
# (a non-Mach-O file keeps its signature in extended attributes, which ditto's zip preserves). The
# main executable is signed last, with the bundle.
executable="$app/Contents/MacOS/$EXECUTABLE"
find "$app/Contents/MacOS" -type f ! -path "$executable" -print0 |
    xargs -0 codesign --force --sign - --timestamp=none
codesign --force --sign - --timestamp=none "$app"
codesign --verify --strict --verbose=2 "$app"
