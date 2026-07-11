#!/bin/bash
#
# upload-dmg.sh — push the released .dmg to Beget Cloud S3.
#
# Credentials are read from the environment — never hardcode them here:
#   export AWS_ACCESS_KEY_ID=...
#   export AWS_SECRET_ACCESS_KEY=...
#
# Usage:
#   ./scripts/upload-dmg.sh [path/to/Again Cleaner.dmg]
#
set -euo pipefail

: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID in the environment}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY in the environment}"

REGION="ru1"
ENDPOINT="https://s3.ru1.storage.beget.cloud"
BUCKET="c73d0519b315-mr-s3"
OBJECT_KEY="again-cleaner/Again-Cleaner.dmg"

cd "$(dirname "$0")/.."
DMG_PATH="${1:-build/release/Again Cleaner.dmg}"

[ -f "$DMG_PATH" ] || { echo "✗ No dmg at: $DMG_PATH (run scripts/release.sh first)"; exit 1; }

echo "▶︎ Uploading $DMG_PATH → $BUCKET/$OBJECT_KEY…"
curl -sS -X PUT -T "$DMG_PATH" \
    --aws-sigv4 "aws:amz:$REGION:s3" \
    --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
    -H "Content-Type: application/x-apple-diskimage" \
    -H "Content-Disposition: attachment; filename=\"Again-Cleaner.dmg\"" \
    -H "Cache-Control: public, max-age=3600" \
    -H "x-amz-acl: public-read" \
    -o /dev/null -w "   PUT status: %{http_code}\n" \
    "$ENDPOINT/$BUCKET/$OBJECT_KEY"

PUBLIC_URL="$ENDPOINT/$BUCKET/$OBJECT_KEY"
echo "▶︎ Verifying public download…"
curl -sS -o /dev/null -w "   GET status: %{http_code}, size: %{size_download}\n" "$PUBLIC_URL"

echo "▶︎ SHA-256 (publish this next to the download link):"
shasum -a 256 "$DMG_PATH"

echo ""
echo "✅ Live at: $PUBLIC_URL"
