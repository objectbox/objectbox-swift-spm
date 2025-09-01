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
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v4.4.1-rc.1/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "0a52ba00073fdf7863ed9620ff332840310a508cbfcc50dea43bb981270cdade"
    ),
    .binaryTarget(
      name: "ObjectBox.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v4.4.1-rc.1/ObjectBox.xcframework.zip",
      checksum: "4f0e8fb875d03e2aa48886abe32ec2ac2a0afb2d153f5665a23932d1f2c9f17e"
    ),
    .binaryTarget(
      name: "ObjectBox-Sync.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v4.4.1-rc.1/ObjectBox-Sync.xcframework.zip",
      checksum: "6f7cbbb160e21b94ceafa7cdd9c18565248b4a48ef69755614ef5806ac5adaa9"
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
