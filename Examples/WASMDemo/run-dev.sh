#!/usr/bin/env bash
set -euo pipefail

SWIFT_SDK="${SWIFT_SDK:-6.3-SNAPSHOT-2026-08-14-a-wasm32-unknown-wasip1-threads}"

npm install

swift package \
  --disable-sandbox \
  --swift-sdk "$SWIFT_SDK" \
  --disable-experimental-prebuilts \
  --allow-writing-to-package-directory \
  js --output ./Bundle

rm -rf Bundle/vendor
mkdir -p Bundle/vendor
cp -R node_modules/@bjorn3/browser_wasi_shim/dist Bundle/vendor/browser_wasi_shim
sed -i.bak "s|'@bjorn3/browser_wasi_shim'|'../vendor/browser_wasi_shim/index.js'|" \
  Bundle/platforms/browser.js
rm -f Bundle/platforms/browser.js.bak

# NB: `serve` gzips responses on the fly and caches nothing, which costs ~2.5s of CPU on every
# request for a module this large and dominates the page load. Serve it uncompressed instead — this
# is localhost, so the extra bytes are free.
npx serve --no-compression
