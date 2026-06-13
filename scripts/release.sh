#!/usr/bin/env bash
# Developer ID signing + notarization release pipeline for hjkl.
# Builds a hardened, signed, notarized, stapled .app for direct distribution.
#
# Run from the project root: ./scripts/release.sh
#
# Required env vars:
#   TEAM_ID        Apple Developer Team ID (10 chars, e.g. ABCDE12345)
#   NOTARY_PROFILE notarytool keychain profile name (default: hjkl-notary)
#
# See RELEASE.md for one-time setup (certificate, notarytool credentials).

set -euo pipefail

# Resolve project root from this script's location so it runs from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="hjkl"
APP_NAME="hjkl.app"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/hjkl.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTS="$BUILD_DIR/ExportOptions.plist"
ZIP_PATH="$BUILD_DIR/hjkl.zip"
APP_PATH="$EXPORT_DIR/$APP_NAME"

banner() {
  echo
  echo "=================================================================="
  echo "  $1"
  echo "=================================================================="
}

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

# --- Preflight: required tools -------------------------------------------
banner "Preflight: checking tools"

for tool in xcodegen xcodebuild; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool not found on PATH. Install it and re-run."
done
xcrun --find notarytool >/dev/null 2>&1 || fail "xcrun notarytool not available. Update Xcode command line tools."
xcrun --find stapler >/dev/null 2>&1 || fail "xcrun stapler not available. Update Xcode command line tools."
echo "xcodegen, xcodebuild, notarytool, stapler present."

# --- Preflight: Developer ID Application identity ------------------------
banner "Preflight: checking Developer ID Application certificate"

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  cat >&2 <<'EOF'
ERROR: No "Developer ID Application" signing identity found in the keychain.

To get one:
  1. Enroll in the Apple Developer Program (https://developer.apple.com/programs/).
  2. In Xcode: Settings > Accounts > your team > Manage Certificates >
     "+" > Developer ID Application. Or create it at
     https://developer.apple.com/account/resources/certificates and import it.
  3. Confirm it is installed:
       security find-identity -v -p codesigning | grep "Developer ID Application"
  4. Re-run this script.
EOF
  exit 1
fi
echo "Developer ID Application identity found."

# --- Preflight: required env vars ---------------------------------------
banner "Preflight: checking env vars"

NOTARY_PROFILE="${NOTARY_PROFILE:-hjkl-notary}"

if [[ -z "${TEAM_ID:-}" ]]; then
  cat >&2 <<'EOF'
ERROR: TEAM_ID is not set.

Set your Apple Team ID (10 chars, find it at
https://developer.apple.com/account under Membership):
  export TEAM_ID=ABCDE12345
EOF
  exit 1
fi

# Verify the notarytool keychain profile exists by probing its history.
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  cat >&2 <<EOF
ERROR: notarytool keychain profile "$NOTARY_PROFILE" not found or invalid.

Create it once with an app-specific password
(generate one at https://appleid.apple.com > Sign-In and Security > App-Specific Passwords):
  xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
    --apple-id <your-apple-id-email> \\
    --team-id "$TEAM_ID" \\
    --password <app-specific-password>

Then re-run. Override the profile name with NOTARY_PROFILE if you used another.
EOF
  exit 1
fi
echo "TEAM_ID=$TEAM_ID, NOTARY_PROFILE=$NOTARY_PROFILE"

# --- Generate the Xcode project -----------------------------------------
banner "Generating Xcode project (xcodegen)"
xcodegen generate

# --- Archive ------------------------------------------------------------
banner "Archiving (Release, hardened runtime, Developer ID)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$ZIP_PATH"
mkdir -p "$BUILD_DIR"

xcodebuild \
  -project hjkl.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  archive

# --- Build ExportOptions.plist from the template ------------------------
banner "Writing $EXPORT_OPTS"
sed "s/REPLACE_TEAM_ID/$TEAM_ID/" ExportOptions.plist > "$EXPORT_OPTS"
echo "teamID set to $TEAM_ID."

# --- Export the signed .app ---------------------------------------------
banner "Exporting signed .app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS"

[[ -d "$APP_PATH" ]] || fail "Expected app not found at $APP_PATH after export."

# --- Zip for notarization -----------------------------------------------
banner "Zipping for notarization"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "Wrote $ZIP_PATH."

# --- Notarize (blocking) ------------------------------------------------
banner "Submitting to notarytool (waiting for result)"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# --- Staple -------------------------------------------------------------
banner "Stapling ticket to the .app"
xcrun stapler staple "$APP_PATH"

# --- Verify -------------------------------------------------------------
banner "Verifying signature and Gatekeeper acceptance"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vvv -t install "$APP_PATH"

# --- Done ---------------------------------------------------------------
banner "Done"
echo "Signed, notarized, stapled app:"
echo "  $ROOT_DIR/$APP_PATH"
echo
echo "Next: package for distribution. Build a DMG (e.g. create-dmg) or zip"
echo "the stapled .app. Notarize the DMG too if you ship a DMG."
