// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "SwiftEmoji",
  platforms: [
      .iOS(.v12),
      .macOS(.v10_13),
      .tvOS(.v12),
      .watchOS(.v4)
  ],
  products: [
      .library(name: "SwiftEmoji", targets: ["SwiftEmoji"])
  ],
  dependencies: [],
  targets: [
      .target(name: "SwiftEmoji")
  ]
)
