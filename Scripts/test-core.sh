#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

swiftc \
  "$PROJECT_DIR/Sources/Whisp/Core/TextPostProcessor.swift" \
  "$PROJECT_DIR/Sources/Whisp/Core/ModifierDoubleTapDetector.swift" \
  "$PROJECT_DIR/Sources/Whisp/Core/Localization.swift" \
  "$PROJECT_DIR/Sources/Whisp/Core/AppSettings.swift" \
  "$PROJECT_DIR/Sources/Whisp/Core/KeychainStore.swift" \
  "$PROJECT_DIR/Sources/Whisp/Services/VercelModelCatalog.swift" \
  "$PROJECT_DIR/Sources/Whisp/Services/VercelGatewayService.swift" \
  "$PROJECT_DIR/Sources/Whisp/Services/RemoteTranscriptionService.swift" \
  "$PROJECT_DIR/Tests/CoreSmoke/main.swift" \
  -o "$TEMP_DIR/core-smoke"

"$TEMP_DIR/core-smoke"
