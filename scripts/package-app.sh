#!/bin/bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="PulseBar"
VERSION="$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
ARCHIVE_PATH="$DIST_DIR/$APP_NAME-$VERSION.zip"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHS="${ARCHS:-$(uname -m)}"

BUILD_ARGUMENTS=(-c release)
for ARCH in $ARCHS; do
    BUILD_ARGUMENTS+=(--arch "$ARCH")
done

cd "$PROJECT_DIR"
swift build "${BUILD_ARGUMENTS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGUMENTS[@]}" --show-bin-path)"

rm -rf "$APP_PATH"
rm -f "$ARCHIVE_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

install -m 755 "$BIN_DIR/$APP_NAME" "$APP_PATH/Contents/MacOS/$APP_NAME"
install -m 644 "$PROJECT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"

CODESIGN_ARGUMENTS=(--force --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    CODESIGN_ARGUMENTS+=(--timestamp)
fi

codesign "${CODESIGN_ARGUMENTS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"

echo "Created $APP_PATH"
echo "Created $ARCHIVE_PATH"
