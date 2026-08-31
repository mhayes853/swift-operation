// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Posts",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "Posts", targets: ["Posts"])
  ],
  dependencies: [
    .package(name: "swift-operation", path: "../.."),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.3")
  ],
  targets: [
    .target(
      name: "Posts",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "SharingOperation", package: "swift-operation")
      ]
    ),
    .testTarget(
      name: "PostsTests",
      dependencies: [
        "Posts",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "SharingOperation", package: "swift-operation")
      ]
    )
  ]
)
