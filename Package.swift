// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
// API reference: https://developer.apple.com/documentation/packagedescription/package

import Foundation
import PackageDescription

let package = Package(
  name: "ObjectBox",
  platforms: [
    // This should match the requirements of ObjectBox.xcframework (so the ObjectBox Swift API and native libraries)
    .macOS(.v11), .iOS(.v15),
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
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/5-preview/ObjectBoxGenerator-5.3.0-beta.1.artifactbundle.zip",
      checksum: "08b418df7276d6f0e2f1ac480246aa2980745c70874019061817e2c71c118d46"
    ),
    .binaryTarget(
      name: "ObjectBox.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/5-preview/ObjectBox-5.3.0-beta.1.xcframework.zip",
      checksum: "335354e2284dbeac1a64da66e0f28f8527254057d8d9f26f3ddd886ac6decc39"
    ),
    .binaryTarget(
      name: "ObjectBox-Sync.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/5-preview/ObjectBox-Sync-5.3.0-beta.1.xcframework.zip",
      checksum: "2a44540a6417d4466e00b50eeff786024402faf258cebcbd4039991f65796b84"
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
