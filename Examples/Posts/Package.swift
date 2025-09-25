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
    .package(url: "https://github.com/mhayes853/swift-operation", branch: "main")
  ],
  targets: [
    .target(
      name: "Posts",
      dependencies: [.product(name: "SharingOperation", package: "swift-operation")]
    )
  ]
)
