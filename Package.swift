// swift-tools-version:5.10

import PackageDescription

let package = Package(
  name: "Scry",
  products: [
    .library(name: "Scry", targets: ["Scry"]),
  ],
  targets: [
    .target(name: "Scry"),
    .testTarget(
      name: "ScryTests",
      dependencies: ["Scry"],
      resources: [.copy("Fixtures")]
    ),
  ]
)
