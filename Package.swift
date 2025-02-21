// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-sharing-query",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)],
  products: [.library(name: "SharingQuery", targets: ["SharingQuery"])],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.0.0")),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3")
  ],
  targets: [
    .target(
      name: "SharingQuery",
      dependencies: [
        "QueryCore",
        .product(name: "Sharing", package: "swift-sharing")
      ]
    ),
    .testTarget(
      name: "SharingQueryTests",
      dependencies: [
        "SharingQuery",
        .product(name: "CustomDump", package: "swift-custom-dump")
      ]
    ),
    .target(name: "QueryCore"),
    .testTarget(name: "QueryCoreTests", dependencies: ["QueryCore"])
  ],
  swiftLanguageModes: [.v6]
)
