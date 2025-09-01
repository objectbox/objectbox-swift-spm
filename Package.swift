// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// API reference: https://developer.apple.com/documentation/packagedescription/package

import Foundation
import PackageDescription

let package = Package(
  name: "ObjectBox",
  platforms: [
    // This should match the requirements of ObjectBox.xcframework (so the ObjectBox Swift API and native libraries)
    .macOS(.v10_15), .iOS(.v12),
  ],
  products: [
    .plugin(name: "ObjectBoxPlugin", targets: ["ObjectBoxGeneratorCommand"]),
    .library(name: "ObjectBox.xcframework", targets: ["ObjectBox.xcframework"]),
    .library(name: "ObjectBox-Sync.xcframework", targets: ["ObjectBox-Sync.xcframework"]),
  ],
  targets: [

    /// MARK: - Binary dependencies
    .binaryTarget(
      name: "ObjectBoxGenerator",
      url:
        "https://github.com/objectbox/objectbox-swift-spm/releases/download/4.4.1/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "4b856b88c28e3c2b59c455caf4c1da4e62e5216da8743ab1e0c3b943b382d71b"
    ),
    .binaryTarget(
      name: "ObjectBox.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spm/releases/download/4.4.1/ObjectBox.xcframework.zip",
      checksum: "8cc0d72b7493e1a7a1e4184f3b77d321d140599a88e99fac6b8fbefcead3d4a9"
    ),
    .binaryTarget(
      name: "ObjectBox-Sync.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spm/releases/download/4.4.1/ObjectBox-Sync.xcframework.zip",
      checksum: "6a1ef518626659fadfe38db1f54a80c7846b5756fb0e69baef7699f4f3c318e8"
    ),

    /// MARK: - Plugin implementations
    .plugin(
      name: "ObjectBoxGeneratorCommand",
      capability: .command(
        intent: .custom(
          verb: "objectbox-generator",  // users will call like 'swift package plugin <verb>'
          description: "Runs the ObjectBox code generator"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Generate files in the package directory"),
          .allowNetworkConnections(
            scope: .all(ports: []),
            reason: "Sending generator analytics to the ObjectBox team"
          ),
        ]
      ),
      dependencies: [
        .target(name: "ObjectBoxGenerator")
      ],
      path: "Plugins/GeneratorCommand"
    ),

  ]
)
