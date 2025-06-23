swift package --swift-sdk "${SWIFT_SDK_ID:-wasm32-unknown-wasip1-threads}" \
    plugin --allow-writing-to-package-directory \
    js --use-cdn --output ./Bundle
npx serve
open http://localhost:3000