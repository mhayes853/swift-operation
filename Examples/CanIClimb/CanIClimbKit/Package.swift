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
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    .package(
      url: "https://github.com/mhayes853/swift-operation",
      branch: "main",
      traits: ["SwiftOperationLogging"]
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-structured-queries",
      from: "0.20.0",
      traits: ["StructuredQueriesTagged"]
    ),
    .package(
      url: "https://github.com/pointfreeco/sqlite-data",
      from: "1.0.0",
      traits: ["SQLiteDataTagged"]
    ),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.2"),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.3.1"),
    .package(url: "https://github.com/evgenyneu/keychain-swift", from: "24.0.0"),
    .package(
      url: "https://github.com/mhayes853/swift-uuidv7",
      from: "0.3.0",
      traits: ["SwiftUUIDV7SQLiteData", "SwiftUUIDV7Tagged", "SwiftUUIDV7Dependencies"]
    ),
    .package(url: "https://github.com/apple/swift-collections", from: "1.2.1"),
    .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.4"),
    .package(url: "https://github.com/n3d1117/ExpandableText", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.6")
  ],
  targets: [
    .target(
      name: "CanIClimbKit",
      dependencies: [
        .product(name: "SharingOperation", package: "swift-operation"),
        .product(name: "SQLiteData", package: "sqlite-data"),
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
        .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
