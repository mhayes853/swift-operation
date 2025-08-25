// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-operation",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
  products: [
    .library(name: "SharingOperation", targets: ["SharingOperation"]),
    .library(name: "Operation", targets: ["Operation"]),
    .library(name: "OperationSwiftUI", targets: ["OperationSwiftUI"])
  ],
  traits: [
    .trait(
      name: "SwiftOperationWebBrowser",
      description:
        "Integrates web browser APIs with the library. (Only enable for WASM Browser Applications)",
      enabledTraits: []
    ),
    .trait(
      name: "SwiftOperationNavigation",
      description: "Integrates SwiftNavigation's UITransaction with SharingOperation."
    ),
    .trait(
      name: "SwiftOperationUIKitNavigation",
      description: "Integrates UIKitNavigation's UIKitAnimation with SharingOperation.",
      enabledTraits: ["SwiftOperationNavigation"]
    ),
    .trait(
      name: "SwiftOperationAppKitNavigation",
      description: "Integrates AppKitNavigation's AppKitAnimation with SharingOperation.",
      enabledTraits: ["SwiftOperationNavigation"]
    ),
    .trait(name: "SwiftOperationLogging", description: "Integrates swift-log with the library.")
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.3"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.7.0"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(
      url: "https://github.com/pointfreeco/swift-identified-collections",
      .upToNextMajor(from: "1.1.0")
    ),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.10.1"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.3.1"),
    .package(url: "https://github.com/apple/swift-log", from: "1.6.3"),
    .package(url: "https://github.com/apple/swift-atomics", from: "1.3.0")
  ],
  targets: [
    .target(
      name: "SharingOperation",
      dependencies: [
        "Operation",
        .product(name: "Sharing", package: "swift-sharing"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(
          name: "SwiftNavigation",
          package: "swift-navigation",
          condition: .when(traits: ["SwiftOperationNavigation"])
        ),
        .product(
          name: "UIKitNavigation",
          package: "swift-navigation",
          condition: .when(
            platforms: [.iOS, .tvOS, .visionOS, .macCatalyst],
            traits: ["SwiftOperationUIKitNavigation"]
          )
        ),
        .product(
          name: "AppKitNavigation",
          package: "swift-navigation",
          condition: .when(
            platforms: [.macOS, .macCatalyst],
            traits: ["SwiftOperationAppKitNavigation"]
          )
        )
      ]
    ),
    .target(name: "Operation", dependencies: ["OperationCore"]),
    .target(
      name: "OperationCore",
      dependencies: [
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
        .product(
          name: "Logging",
          package: "swift-log",
          condition: .when(traits: ["SwiftOperationLogging"])
        ),
        .product(name: "Atomics", package: "swift-atomics")
      ],
      swiftSettings: [
        .define(
          "SWIFT_OPERATION_EXIT_TESTABLE_PLATFORM",
          .when(platforms: [.macOS, .linux, .windows])
        )
      ]
    ),
    .target(name: "OperationSwiftUI", dependencies: ["Operation"]),
    .target(
      name: "OperationTestHelpers",
      dependencies: ["Operation", .product(name: "CustomDump", package: "swift-custom-dump")]
    )
  ],
  swiftLanguageModes: [.v6]
)

#if !os(Windows)
  package.dependencies.append(
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", from: "0.32.1"),
  )
  package.targets.append(
    contentsOf: [
      .target(
        name: "OperationWebBrowser",
        dependencies: [
          "OperationCore",
          .product(
            name: "JavaScriptKit",
            package: "JavaScriptKit",
            condition: .when(platforms: [
              .iOS, .tvOS, .macOS, .watchOS, .visionOS, .macCatalyst, .linux, .wasi
            ])
          ),
          .product(
            name: "JavaScriptEventLoop",
            package: "JavaScriptKit",
            condition: .when(platforms: [
              .iOS, .tvOS, .macOS, .watchOS, .visionOS, .macCatalyst, .linux, .wasi
            ])
          )
        ]
      ),
      .testTarget(
        name: "OperationWebBrowserTests",
        dependencies: [
          "OperationWebBrowser",
          .product(
            name: "JavaScriptEventLoopTestSupport",
            package: "JavaScriptKit",
            condition: .when(platforms: [.wasi])
          )
        ]
      )
    ]
  )
  let operationTarget = package.targets.first { $0.name == "Operation" }
  operationTarget?.dependencies
    .append(
      .target(name: "OperationWebBrowser", condition: .when(traits: ["SwiftOperationWebBrowser"]))
    )
#endif

var operationTestsDependencies: [Target.Dependency] = [
  "Operation",
  "OperationTestHelpers",
  .product(name: "CustomDump", package: "swift-custom-dump"),
  .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
]

if Context.environment["TEST_WASM"] != "1" {
  package.targets.append(
    contentsOf: [
      .testTarget(
        name: "SharingOperationTests",
        dependencies: [
          "SharingOperation",
          "OperationTestHelpers",
          .product(name: "CustomDump", package: "swift-custom-dump"),
          .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
        ]
      ),
      .testTarget(name: "OperationTests", dependencies: operationTestsDependencies),
      .testTarget(
        name: "OperationSwiftUITests",
        dependencies: [
          "OperationSwiftUI",
          "OperationTestHelpers",
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
