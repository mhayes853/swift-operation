// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
  name: "swift-query",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)],
  products: [
    .library(name: "SharingQuery", targets: ["SharingQuery"]),
    .library(name: "Query", targets: ["Query"]),
    .library(name: "QuerySwiftUI", targets: ["QuerySwiftUI"])
  ],
  traits: [
    .trait(
      name: "WebBrowser",
      description:
        "Integrates web browser APIs with the library. (Only enable for WASM Browser Applications)",
      enabledTraits: []
    ),
    .trait(
      name: "SwiftNavigation",
      description: "Integrates SwiftNavigation's UITransaction with SharingQuery."
    ),
    .trait(
      name: "UIKitNavigation",
      description: "Integrates UIKitNavigation's UIKitAnimation with SharingQuery.",
      enabledTraits: ["SwiftNavigation"]
    ),
    .trait(
      name: "AppKitNavigation",
      description: "Integrates AppKitNavigation's AppKitAnimation with SharingQuery.",
      enabledTraits: ["SwiftNavigation"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.0"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.4.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(
      url: "https://github.com/pointfreeco/swift-identified-collections",
      .upToNextMajor(from: "1.1.0")
    ),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.26.1"),
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.1"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.3.0")
  ],
  targets: [
    .target(
      name: "SharingQuery",
      dependencies: [
        "Query",
        .product(name: "Sharing", package: "swift-sharing"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(
          name: "SwiftNavigation",
          package: "swift-navigation",
          condition: .when(traits: ["SwiftNavigation"])
        ),
        .product(
          name: "UIKitNavigation",
          package: "swift-navigation",
          condition: .when(
            platforms: [.iOS, .tvOS, .visionOS, .macCatalyst],
            traits: ["UIKitNavigation"]
          )
        ),
        .product(
          name: "AppKitNavigation",
          package: "swift-navigation",
          condition: .when(platforms: [.macOS, .macCatalyst], traits: ["AppKitNavigation"])
        )
      ]
    ),
    .target(
      name: "Query",
      dependencies: [
        "QueryCore",
        .target(name: "QueryBrowser", condition: .when(traits: ["browser"]))
      ]
    ),
    .target(
      name: "QueryBrowser",
      dependencies: [
        "QueryCore",
        .product(
          name: "JavaScriptKit",
          package: "JavaScriptKit",
          condition: .when(platforms: [.wasi])
        )
      ]
    ),
    .target(
      name: "QueryCore",
      dependencies: [
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections")
      ]
    ),
    .target(name: "QuerySwiftUI", dependencies: ["Query"]),
    .target(name: "QueryTestHelpers", dependencies: ["Query"]),
    .testTarget(
      name: "QueryWASMTests",
      dependencies: [
        "QueryBrowser",
        .product(
          name: "JavaScriptEventLoopTestSupport",
          package: "JavaScriptKit",
          condition: .when(platforms: [.wasi])
        )
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)

var queryTestsDependencies: [Target.Dependency] = [
  "Query",
  "QueryTestHelpers",
  .product(name: "CustomDump", package: "swift-custom-dump"),
  .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
]

if ProcessInfo.processInfo.environment["TEST_WASM"] != "1" {
  package.targets.append(
    contentsOf: [
      .testTarget(
        name: "SharingQueryTests",
        dependencies: [
          "SharingQuery",
          "QueryTestHelpers",
          .product(name: "CustomDump", package: "swift-custom-dump"),
          .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
        ]
      ),
      .testTarget(name: "QueryTests", dependencies: queryTestsDependencies),
      .testTarget(
        name: "QuerySwiftUITests",
        dependencies: [
          "QuerySwiftUI",
          "QueryTestHelpers",
          .product(name: "CustomDump", package: "swift-custom-dump"),
          .product(
            name: "ViewInspector",
            package: "ViewInspector",
            condition: .when(platforms: [.iOS, .macOS, .watchOS, .tvOS, .visionOS])
          )
        ]
      )
    ]
  )
}
