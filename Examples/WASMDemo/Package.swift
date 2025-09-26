// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WASMDemo",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(
      url: "https://github.com/mhayes853/swift-sharing",
      branch: "fix-macos-toolchain-build"
    ),
    .package(
      url: "https://github.com/mhayes853/swift-dependencies",
      branch: "fix-wasm-build"
    ),
    .package(
      url: "https://github.com/mhayes853/swift-operation",
      branch: "main",
      traits: ["SwiftOperationNavigation", "SwiftOperationLogging", "SwiftOperationWebBrowser"]
    ),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.36.0")
  ],
  targets: [
    .executableTarget(name: "WASMDemo", dependencies: ["WASMDemoCore"]),
    .target(
      name: "WASMDemoCore",
      dependencies: [
        .product(name: "SharingOperation", package: "swift-operation"),
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
