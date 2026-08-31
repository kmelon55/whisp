#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
RELEASE_DIR="$PROJECT_DIR/release"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ARCHIVE="$RELEASE_DIR/Whisp-$VERSION.zip"

"$PROJECT_DIR/Scripts/build-app.sh"
mkdir -p "$RELEASE_DIR"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$PROJECT_DIR/dist/Whisp.app" "$ARCHIVE"

codesign --verify --deep --strict --verbose=2 "$PROJECT_DIR/dist/Whisp.app"
spctl --assess --type execute --verbose=2 "$PROJECT_DIR/dist/Whisp.app" || true
shasum -a 256 "$ARCHIVE"
echo "$ARCHIVE"
