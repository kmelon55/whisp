#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
RELEASE_DIR="$PROJECT_DIR/release"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ARCHIVE="$RELEASE_DIR/Whisp-$VERSION.dmg"

"$PROJECT_DIR/Scripts/build-app.sh"
mkdir -p "$RELEASE_DIR"
STAGING_DIR="$(mktemp -d "$RELEASE_DIR/Whisp-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
rm -f "$ARCHIVE"
ditto "$PROJECT_DIR/dist/Whisp.app" "$STAGING_DIR/Whisp.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
  -volname "Whisp" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$ARCHIVE"

codesign --verify --deep --strict --verbose=2 "$PROJECT_DIR/dist/Whisp.app"
spctl --assess --type execute --verbose=2 "$PROJECT_DIR/dist/Whisp.app" || true
hdiutil verify "$ARCHIVE"
shasum -a 256 "$ARCHIVE"
echo "$ARCHIVE"
