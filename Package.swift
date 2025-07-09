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
        "https://github.com/objectbox/objectbox-swift-spm/releases/download/4.4.0/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "1d5e818c86d77cfbcb3d2fc14890c0bdea9fb28cbf23196c2543803220c4787a"
    ),
    .binaryTarget(
      name: "ObjectBox.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spm/releases/download/4.4.0/ObjectBox.xcframework.zip",
      checksum: "be3ccf934abb0e312d870478384ec6d56a08c0bef3f4649da29e525790524c4c"
    ),
    .binaryTarget(
      name: "ObjectBox-Sync.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spm/releases/download/4.4.0/ObjectBox-Sync.xcframework.zip",
      checksum: "1db1a38da2dd022fb0c3464182483422030e05c24aadb054cb6a57d943f7454b"
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
          .writeToPackageDirectory(reason: "Generate files in the package directory")
        ]
      ),
      dependencies: [
        .target(name: "ObjectBoxGenerator")
      ],
      path: "Plugins/GeneratorCommand"
    ),

  ]
)
