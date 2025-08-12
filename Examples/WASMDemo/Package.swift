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
      url: "https://github.com/mhayes853/swift-query",
      branch: "main",
      traits: ["SwiftQueryNavigation", "SwiftQueryLogging", "SwiftQueryWebBrowser"]
    ),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.32.1")
  ],
  targets: [
    .executableTarget(name: "WASMDemo", dependencies: ["WASMDemoCore"]),
    .target(
      name: "WASMDemoCore",
      dependencies: [
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
