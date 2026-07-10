#!/bin/bash
#
# release.sh — Build, sign (Developer ID), notarize, staple and package
# "Again Cleaner" into a distributable .dmg.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate installed in the login keychain.
#        Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates… ▸ + ▸ Developer ID Application
#   2. Stored notarization credentials under the profile name below:
#        xcrun notarytool store-credentials "AgainCleaner-notary" \
#          --apple-id "you@appleid.com" --team-id 39CP3623CD \
#          --password "xxxx-xxxx-xxxx-xxxx"   # app-specific password
#
# Usage:
#   ./scripts/release.sh
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
PROJECT="Again Cleaner.xcodeproj"
SCHEME="Again Cleaner"
CONFIG="Release"
APP_NAME="Again Cleaner"
NOTARY_PROFILE="AgainCleaner-notary"

# Resolve to the project root (parent of this script's directory).
cd "$(dirname "$0")/.."

BUILD_DIR="$(pwd)/build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

echo "▶︎ Cleaning previous build…"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Pretty-print xcodebuild output if xcpretty is available, otherwise pass through.
if command -v xcpretty >/dev/null 2>&1; then
    PRETTY=(xcpretty)
else
    PRETTY=(cat)
fi

# ── 1. Archive ──────────────────────────────────────────────────────────────
echo "▶︎ Archiving ($CONFIG)…"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    | "${PRETTY[@]}"

# ── 2. Export with Developer ID ─────────────────────────────────────────────
echo "▶︎ Exporting (Developer ID)…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "ExportOptions.plist"

# ── 3. Notarize ─────────────────────────────────────────────────────────────
# Zip the .app for submission (notarytool wants a zip/dmg/pkg).
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
echo "▶︎ Zipping for notarization…"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "▶︎ Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# ── 4. Staple ───────────────────────────────────────────────────────────────
echo "▶︎ Stapling ticket…"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

# ── 5. Package into a .dmg ──────────────────────────────────────────────────
echo "▶︎ Building .dmg…"
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

# Notarize & staple the .dmg too, so the download itself passes Gatekeeper.
echo "▶︎ Notarizing the .dmg…"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
xcrun stapler staple "$DMG_PATH"

echo ""
echo "✅ Done."
echo "   App: $APP_PATH"
echo "   DMG: $DMG_PATH"
