#!/bin/bash
#
# release.sh — Build, sign (Developer ID), notarize, staple and package
# "Again Cleaner" into a distributable .dmg.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate installed in the login keychain.
#        Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates… ▸ + ▸ Developer ID Application
#   2. Notarization credentials, either:
#      a) an App Store Connect API key (preferred — nothing lives in the
#         keychain, so a keychain reset can't take it away):
#           export NOTARY_KEY_ID=UW455J9MMK          # AuthKey_<id>.p8 in the repo root (gitignored)
#           export NOTARY_ISSUER=<issuer uuid>       # App Store Connect ▸ Users and Access ▸ Integrations
#      b) or a stored keychain profile:
#           xcrun notarytool store-credentials "AgainCleaner-notary" \
#             --apple-id "you@appleid.com" --team-id 39CP3623CD \
#             --password "xxxx-xxxx-xxxx-xxxx"   # app-specific password
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
DMG_IDENTITY="Developer ID Application: MEDIARAIS, OOO (39CP3623CD)"

# Resolve to the project root (parent of this script's directory).
cd "$(dirname "$0")/.."

BUILD_DIR="$(pwd)/build/release"

# Notary credentials: the team's App Store Connect API key "Notary"
# (Developer role). IDs aren't secret — only AuthKey_<id>.p8 is, and it's
# gitignored. Override via env; set NOTARY_KEY_ID= to use the keychain profile.
NOTARY_KEY_ID="${NOTARY_KEY_ID-C65777AY8Z}"
NOTARY_ISSUER="${NOTARY_ISSUER-47165295-f7cd-421d-8ff4-a5cd08675bc5}"
if [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER:-}" ]; then
    NOTARY_KEY="$(pwd)/AuthKey_${NOTARY_KEY_ID}.p8"
    [ -f "$NOTARY_KEY" ] || { echo "✗ Missing $NOTARY_KEY"; exit 1; }
    NOTARY_AUTH=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
    # Same key lets xcodebuild use cloud-managed Developer ID signing.
    XCODE_AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$NOTARY_KEY"
                -authenticationKeyID "$NOTARY_KEY_ID" -authenticationKeyIssuerID "$NOTARY_ISSUER")
else
    NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
    XCODE_AUTH=(-allowProvisioningUpdates)
fi
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
    "${XCODE_AUTH[@]}" \
    | "${PRETTY[@]}"

# ── 2. Export with Developer ID ─────────────────────────────────────────────
echo "▶︎ Exporting (Developer ID)…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "ExportOptions.plist" \
    "${XCODE_AUTH[@]}"

# ── 3. Notarize ─────────────────────────────────────────────────────────────
# Zip the .app for submission (notarytool wants a zip/dmg/pkg).
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
echo "▶︎ Zipping for notarization…"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "▶︎ Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$ZIP_PATH" \
    "${NOTARY_AUTH[@]}" \
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

# Sign the .dmg itself — an unsigned image fails `spctl -t open` even when
# notarized, so Gatekeeper would still warn on the download.
# Cloud-managed signing (export above) leaves no local identity; the image is
# then shipped unsigned but notarized + stapled, and the app inside is signed.
if security find-identity -v -p codesigning | grep -qF "$DMG_IDENTITY"; then
    echo "▶︎ Signing the .dmg…"
    codesign --sign "$DMG_IDENTITY" --timestamp "$DMG_PATH"
else
    echo "⚠︎ No local \"$DMG_IDENTITY\" — leaving the .dmg unsigned (app inside is signed)."
fi

# Notarize & staple the .dmg too, so the download itself passes Gatekeeper.
echo "▶︎ Notarizing the .dmg…"
xcrun notarytool submit "$DMG_PATH" \
    "${NOTARY_AUTH[@]}" \
    --wait
xcrun stapler staple "$DMG_PATH"

echo ""
echo "✅ Done."
echo "   App: $APP_PATH"
echo "   DMG: $DMG_PATH"
