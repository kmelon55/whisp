#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_BUNDLE="$PROJECT_DIR/dist/Whisp.app"
CONTENTS="$APP_BUNDLE/Contents"
SIGN_IDENTITY="${WHISP_SIGN_IDENTITY:--}"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$PROJECT_DIR/.build/release/Whisp" "$CONTENTS/MacOS/Whisp"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
"$PROJECT_DIR/Scripts/build-icon.sh" "$CONTENTS/Resources/Whisp.icns"
mkdir -p "$CONTENTS/Frameworks"
ditto \
  "$PROJECT_DIR/.build/release/Sparkle.framework" \
  "$CONTENTS/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "$CONTENTS/MacOS/Whisp"

SPARKLE_FRAMEWORK="$CONTENTS/Frameworks/Sparkle.framework"
SPARKLE_VERSION="$SPARKLE_FRAMEWORK/Versions/B"
SPARKLE_COMPONENTS=(
  "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
  "$SPARKLE_VERSION/XPCServices/Installer.xpc"
  "$SPARKLE_VERSION/Updater.app"
  "$SPARKLE_FRAMEWORK"
)

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  # 로컬 빌드도 같은 앱으로 인식되도록 빌드마다 바뀌지 않는 DR을 사용합니다.
  for component in "${SPARKLE_COMPONENTS[@]}"; do
    codesign --force --sign - \
      --preserve-metadata=identifier,entitlements,requirements,flags \
      "$component"
  done
  codesign --force --sign - \
    --requirements '=designated => identifier "app.whisp.mac-dictation"' \
    "$APP_BUNDLE"
else
  for component in "${SPARKLE_COMPONENTS[@]}"; do
    codesign --force --options runtime --timestamp \
      --preserve-metadata=identifier,entitlements,requirements,flags \
      --sign "$SIGN_IDENTITY" \
      "$component"
  done
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$APP_BUNDLE"
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "$APP_BUNDLE"
