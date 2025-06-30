// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// TODO: - This needs to be merged: https://github.com/pointfreeco/swift-dependencies/pull/372

let package = Package(
  name: "WASMDemo",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(
      url: "https://github.com/zp-dzordz/swift-dependencies",
      branch: "fix-for-WASM-builds"
    ),
    .package(
      url: "https://github.com/mhayes853/swift-sharing",
      branch: "fix-macos-toolchain-build"
    ),
    .package(
      url: "https://github.com/mhayes853/swift-query",
      branch: "main",
      traits: ["SwiftQueryNavigation", "SwiftQueryLogging", "SwiftQueryWebBrowser"]
    ),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.26.1")
  ],
  targets: [
    .executableTarget(name: "WASMDemo", dependencies: ["WASMDemoCore"]),
    .target(
      name: "WASMDemoCore",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "SharingQuery", package: "swift-query"),
        .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        .product(name: "JavaScriptEventLoop", package: "JavaScriptKit")
      ]
    ),
    .testTarget(
      name: "WASMDemoTests",
      dependencies: [
        "WASMDemoCore",
        .product(name: "JavaScriptEventLoopTestSupport", package: "JavaScriptKit")
      ]
    )
  ]
)
