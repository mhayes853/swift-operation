#!/usr/bin/env bash
set -euo pipefail

TEST_WASM=1 swift package \
  --disable-sandbox \
  --swift-sdk wasm32-unknown-wasip1 \
  js test --environment browser
