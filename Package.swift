// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

let package = Package(
  name: "swift-query",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6)],
  products: [
    .library(name: "SharingQuery", targets: ["SharingQuery"]),
    .library(name: "QueryCore", targets: ["QueryCore"]),
    .library(name: "QueryWASM", targets: ["QueryWASM"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.3.3"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(
      url: "https://github.com/pointfreeco/swift-identified-collections",
      .upToNextMajor(from: "1.1.0")
    ),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
    .package(url: "https://github.com/swiftwasm/JavaScriptKit", branch: "main")
  ],
  targets: [
    .target(
      name: "SharingQuery",
      dependencies: [
        "QueryCore",
        .product(name: "Sharing", package: "swift-sharing")
      ]
    ),
    .target(
      name: "QueryCore",
      dependencies: [
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
        .product(name: "IdentifiedCollections", package: "swift-identified-collections")
      ]
    ),
    .target(
      name: "QueryWASM",
      dependencies: [
        "QueryCore",
        .product(
          name: "JavaScriptKit",
          package: "JavaScriptKit",
          condition: .when(platforms: [.wasi])
        )
      ]
    ),
    .testTarget(
      name: "QueryWASMTests",
      dependencies: [
        "QueryWASM",
        .product(name: "CustomDump", package: "swift-custom-dump"),
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

if ProcessInfo.processInfo.environment["TEST_WASM"] != "1" {
  package.targets.append(
    contentsOf: [
      .testTarget(
        name: "SharingQueryTests",
        dependencies: [
          "SharingQuery",
          .product(name: "CustomDump", package: "swift-custom-dump")
        ]
      ),
      .testTarget(
        name: "QueryCoreTests",
        dependencies: [
          "QueryCore",
          .product(name: "CustomDump", package: "swift-custom-dump"),
          .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
        ]
      )
    ]
  )
}
