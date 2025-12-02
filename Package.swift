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
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v5.1.0-rc.1/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "5f10e5cef769461290e1c30d51c647bc36955b5d7af0f4f09ffb9a90de3cdb54"
    ),
    .binaryTarget(
      name: "ObjectBox.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v5.1.0-rc.1/ObjectBox.xcframework.zip",
      checksum: "92c7567307a185d7bfc20c2af136cbe49da8309865af1cdf4f48ce2443c399c1"
    ),
    .binaryTarget(
      name: "ObjectBox-Sync.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v5.1.0-rc.1/ObjectBox-Sync.xcframework.zip",
      checksum: "107736cf61cd7d8e1f72bbdb9208df617568868545c6a2116d7ec0f73a096c61"
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
