// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WASMDemo",
  platforms: [.macOS(.v15)],
  dependencies: [
    // NB: SwiftPM derives a path dependency's identity from the directory name, which is not
    // "swift-operation" when the repository is cloned under its GitHub name or checked out as a
    // git worktree. Name the dependency explicitly so the `package: "swift-operation"` references
    // below resolve wherever the checkout happens to live.
    .package(
      name: "swift-operation",
      path: "../..",
      traits: ["SwiftOperationLogging", "SwiftOperationWebBrowser"]
    ),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.58.0"),
    // NB: swift-dependencies links CombineSchedulers unconditionally, and combine-schedulers 1.1.0
    // added a non-Darwin lock that calls pthread APIs without importing WASILibc, which does not
    // compile for wasm32-unknown-wasip1. Pin below 1.1.0 until that is fixed upstream.
    .package(url: "https://github.com/pointfreeco/combine-schedulers", "1.0.2"..<"1.1.0")
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
