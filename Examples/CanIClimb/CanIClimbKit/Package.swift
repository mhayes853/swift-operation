// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CanIClimbKit",
  platforms: [.macOS(.v26), .iOS(.v26)],
  products: [
    .library(name: "CanIClimbKit", targets: ["CanIClimbKit"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/mhayes853/swift-query",
      branch: "main",
      traits: ["SwiftQueryLogging"]
    ),
    .package(url: "https://github.com/pointfreeco/sharing-grdb-icloud", branch: "cloudkit"),
    .package(url: "https://github.com/mhayes853/structured-queries-tagged", from: "0.1.1")
  ],
  targets: [
    .target(
      name: "CanIClimbKit",
      dependencies: [
        .product(name: "SharingQuery", package: "swift-query"),
        .product(name: "SharingGRDB", package: "sharing-grdb-icloud"),
        .product(name: "StructuredQueriesTagged", package: "structured-queries-tagged")
      ]
    ),
    .testTarget(name: "CanIClimbKitTests", dependencies: ["CanIClimbKit"])
  ],
  swiftLanguageModes: [.v6]
)
