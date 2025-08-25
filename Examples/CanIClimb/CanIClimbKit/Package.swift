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
      traits: ["SwiftOperationLogging"]
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-structured-queries",
      from: "0.12.1",
      traits: ["StructuredQueriesTagged"]
    ),
    .package(url: "https://github.com/pointfreeco/sharing-grdb", branch: "cloudkit"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.2"),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.3.1"),
    .package(url: "https://github.com/evgenyneu/keychain-swift", from: "24.0.0"),
    .package(
      url: "https://github.com/mhayes853/swift-uuidv7",
      branch: "sharing-grdb-icloud",
      traits: ["SwiftUUIDV7SharingGRDB", "SwiftUUIDV7Tagged", "SwiftUUIDV7Dependencies"]
    ),
    .package(url: "https://github.com/apple/swift-collections", from: "1.2.1"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.4"),
    .package(url: "https://github.com/n3d1117/ExpandableText", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "CanIClimbKit",
      dependencies: [
        .product(name: "SharingOperation", package: "swift-query"),
        .product(name: "SharingGRDB", package: "sharing-grdb"),
        .product(name: "SwiftUINavigation", package: "swift-navigation"),
        .product(name: "UIKitNavigation", package: "swift-navigation"),
        .product(name: "KeychainSwift", package: "keychain-swift"),
        .product(name: "UUIDV7", package: "swift-uuidv7"),
        .product(name: "DequeModule", package: "swift-collections"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(
          name: "ExpandableText",
          package: "ExpandableText",
          condition: .when(platforms: [.iOS])
        )
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
