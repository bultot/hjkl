#!/usr/bin/env bash
# Regenerate App/Assets.xcassets/AppIcon.appiconset from App/AppIconView.swift.
#
# Builds the app, runs it once with HJKL_RENDER_ICON so it renders AppIconView
# natively at each appiconset pixel size (16…1024), drops the PNGs into the
# AppIcon.appiconset, then rebuilds so the catalog compiles with the new icon.
#
# Run from anywhere: ./scripts/gen-icon.sh
# Re-run whenever AppIconView.swift changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="hjkl"
BUILD_DIR="build"
APPICONSET="App/Assets.xcassets/AppIcon.appiconset"
TMP_DIR="$BUILD_DIR/icon-render"

banner() { echo; echo "=== $1 ==="; }
fail()   { echo "ERROR: $1" >&2; exit 1; }

for tool in xcodegen xcodebuild; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool not found on PATH."
done

build() {
  xcodebuild -project hjkl.xcodeproj -scheme "$SCHEME" -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build >/dev/null
}

banner "Generating Xcode project"
xcodegen generate >/dev/null

# Bootstrap: blank the appiconset so the render build compiles even if the PNGs
# are missing or stale (actool accepts an AppIcon set with no images).
cat > "$APPICONSET/Contents.json" <<'JSON'
{
  "images" : [],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

banner "Building app (for the icon renderer)"
build
BIN="$BUILD_DIR/Build/Products/Debug/$SCHEME.app/Contents/MacOS/$SCHEME"
[ -x "$BIN" ] || fail "built binary not found at $BIN"

banner "Rendering icon PNGs"
rm -rf "$TMP_DIR"
HJKL_RENDER_ICON="$TMP_DIR" "$BIN"
for px in 16 32 64 128 256 512 1024; do
  [ -f "$TMP_DIR/icon_$px.png" ] || fail "renderer did not produce icon_$px.png"
done

banner "Writing appiconset"
cp "$TMP_DIR"/icon_*.png "$APPICONSET/"
cat > "$APPICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16.png" },
    { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_64.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_1024.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

banner "Rebuilding with the new icon"
build

echo
echo "Done. AppIcon.appiconset updated from App/AppIconView.swift."
