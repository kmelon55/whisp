#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
RELEASE_DIR="$PROJECT_DIR/release"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
ARCHIVE="$RELEASE_DIR/Whisp-$VERSION.dmg"
SIGN_IDENTITY="${WHISP_SIGN_IDENTITY:--}"
BACKGROUND_SVG="$PROJECT_DIR/Resources/DMG/background.svg"
RW_IMAGE="$RELEASE_DIR/Whisp-$VERSION-rw.dmg"

"$PROJECT_DIR/Scripts/build-app.sh"
mkdir -p "$RELEASE_DIR"
STAGING_DIR="$(mktemp -d "$RELEASE_DIR/Whisp-dmg.XXXXXX")"
MOUNT_DIR="$(mktemp -d "$RELEASE_DIR/Whisp-mount.XXXXXX")"
MOUNTED=0

cleanup() {
  if (( MOUNTED )); then
    hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGING_DIR" "$MOUNT_DIR"
  rm -f "$RW_IMAGE"
}
trap cleanup EXIT

rm -f "$ARCHIVE" "$RW_IMAGE"
ditto "$PROJECT_DIR/dist/Whisp.app" "$STAGING_DIR/Whisp.app"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"
sips -s format png "$BACKGROUND_SVG" \
  --out "$STAGING_DIR/.background/background.png" >/dev/null
sips -s dpiWidth 144 -s dpiHeight 144 \
  "$STAGING_DIR/.background/background.png" >/dev/null

hdiutil create \
  -volname "Whisp" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$RW_IMAGE"

hdiutil attach "$RW_IMAGE" \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_DIR" >/dev/null
MOUNTED=1
DISK_NAME="${MOUNT_DIR:t}"

osascript <<APPLESCRIPT
with timeout of 30 seconds
  tell application "Finder"
    tell disk "$DISK_NAME"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set pathbar visible of container window to false
      set bounds of container window to {200, 120, 800, 520}
      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 100
      set text size of viewOptions to 13
      set background picture of viewOptions to file ".background:background.png"
      set position of item "Whisp.app" to {175, 190}
      set position of item "Applications" to {425, 190}
      delay 2
      close
    end tell
  end tell
end timeout
APPLESCRIPT

if [[ ! -f "$MOUNT_DIR/.DS_Store" ]]; then
  echo "Finder did not save the DMG window layout." >&2
  exit 1
fi

sync
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNTED=0

hdiutil convert "$RW_IMAGE" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$ARCHIVE"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$ARCHIVE"
  codesign --verify --verbose=2 "$ARCHIVE"
fi

codesign --verify --deep --strict --verbose=2 "$PROJECT_DIR/dist/Whisp.app"
spctl --assess --type execute --verbose=2 "$PROJECT_DIR/dist/Whisp.app" || true
hdiutil verify "$ARCHIVE"
shasum -a 256 "$ARCHIVE"
echo "$ARCHIVE"
