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
    .package(
      url: "https://github.com/pointfreeco/sharing-grdb-icloud",
      revision: "f3a9c5a3c0942b9e8056736b3994ac07b381ea6c"
    ),
    .package(url: "https://github.com/mhayes853/structured-queries-tagged", from: "0.1.1"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.2"),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.3.1"),
    .package(url: "https://github.com/evgenyneu/keychain-swift", from: "24.0.0"),
    .package(
      url: "https://github.com/mhayes853/swift-uuidv7",
      branch: "sharing-grdb-icloud",
      traits: ["SwiftUUIDV7SharingGRDB", "SwiftUUIDV7Tagged"]
    )
  ],
  targets: [
    .target(
      name: "CanIClimbKit",
      dependencies: [
        .product(name: "SharingQuery", package: "swift-query"),
        .product(name: "SharingGRDB", package: "sharing-grdb-icloud"),
        .product(name: "StructuredQueriesTagged", package: "structured-queries-tagged"),
        .product(name: "SwiftUINavigation", package: "swift-navigation"),
        .product(name: "UIKitNavigation", package: "swift-navigation"),
        .product(name: "KeychainSwift", package: "keychain-swift"),
        .product(name: "UUIDV7", package: "swift-uuidv7")
      ]
    ),
    .testTarget(
      name: "CanIClimbKitTests",
      dependencies: [
        "CanIClimbKit",
        .product(name: "DependenciesTestSupport", package: "swift-dependencies")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
