#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")"
APP_PATH="$PROJECT_DIR/dist/PulseBar.app"
ARCHIVE_PATH="$PROJECT_DIR/dist/PulseBar-$VERSION.zip"

: "${APPLE_ID:?Set APPLE_ID to the Apple Developer account email}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to the Apple Developer Team ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD for notarization}"

test -d "$APP_PATH"
test -f "$ARCHIVE_PATH"

xcrun notarytool submit "$ARCHIVE_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"
spctl --assess --type execute --verbose=2 "$APP_PATH"

echo "Notarized and stapled $ARCHIVE_PATH"
