#!/usr/bin/env bash
set -euo pipefail

SWIFT_SDK="${SWIFT_SDK:-6.3-SNAPSHOT-2026-08-14-a-wasm32-unknown-wasip1-threads}"

swift package \
  --disable-sandbox \
  --swift-sdk "$SWIFT_SDK" \
  --disable-experimental-prebuilts \
  js test --environment browser
