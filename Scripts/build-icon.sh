#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
SOURCE="$PROJECT_DIR/Resources/AppIcon.svg"
OUTPUT="${1:-$PROJECT_DIR/dist/Whisp.icns}"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/Whisp-icon.XXXXXX")"
ICONSET="$TEMP_DIR/Whisp.iconset"
MASTER_PNG="$ICONSET/master.png"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$ICONSET"

sips -s format png "$SOURCE" --out "$MASTER_PNG" >/dev/null

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$MASTER_PNG" \
    --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  sips -z "$double_size" "$double_size" "$MASTER_PNG" \
    --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

rm "$MASTER_PNG"
mkdir -p "${OUTPUT:h}"
iconutil --convert icns --output "$OUTPUT" "$ICONSET"
