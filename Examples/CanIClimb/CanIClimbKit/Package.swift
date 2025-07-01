// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CanIClimbKit",
  // platforms: [.macOS(.)],
  products: [
    .library(name: "CanIClimbKit", targets: ["CanIClimbKit"])
  ],
  targets: [
    .target(name: "CanIClimbKit"),
    .testTarget(name: "CanIClimbKitTests", dependencies: ["CanIClimbKit"])
  ]
)
