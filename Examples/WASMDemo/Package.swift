// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WASMDemo",
  platforms: [.macOS(.v10_15)],
  dependencies: [
    .package(
      url: "https://github.com/mhayes853/swift-query",
      branch: "main",
      traits: ["SwiftQueryNavigation", "SwiftQueryLogging", "SwiftQueryWebBrowser"]
    )
  ],
  targets: [
    .executableTarget(
      name: "WASMDemo",
      dependencies: [.product(name: "SharingQuery", package: "swift-query")]
    )
  ]
)
