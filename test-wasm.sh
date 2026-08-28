#!/usr/bin/env bash
set -euo pipefail

# NB: The WebAssembly SDK bundle ships both a regular and an embedded Swift SDK for the
# wasm32-unknown-wasip1 triple, and selecting by triple picks between them arbitrarily. The
# embedded one has no Foundation, so select the regular SDK by its identifier instead.
SWIFT_SDK="${SWIFT_SDK:-swift-6.3.2-RELEASE_wasm}"

TEST_WASM=1 swift package \
  --disable-sandbox \
  --swift-sdk "$SWIFT_SDK" \
  js test --environment browser
