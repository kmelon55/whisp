#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_BUNDLE="$PROJECT_DIR/dist/Whisp.app"
CONTENTS="$APP_BUNDLE/Contents"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$PROJECT_DIR/.build/release/Whisp" "$CONTENTS/MacOS/Whisp"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
mkdir -p "$CONTENTS/Frameworks"
ditto \
  "$PROJECT_DIR/.build/release/Sparkle.framework" \
  "$CONTENTS/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "$CONTENTS/MacOS/Whisp"
# 로컬 ad-hoc 빌드도 같은 앱으로 인식되도록 빌드마다 바뀌지 않는 DR을 사용합니다.
codesign --force --deep --sign - "$CONTENTS/Frameworks/Sparkle.framework"
codesign --force --sign - \
  --requirements '=designated => identifier "app.whisp.mac-dictation"' \
  "$APP_BUNDLE"

echo "$APP_BUNDLE"
