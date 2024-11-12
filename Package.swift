// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let package = Package(
  name: "ObjectBox",

  products: [
    .plugin(name: "GeneratorCommand", targets: ["GeneratorCommand"]),
    .library(
      name: "ObjectBox.xcframework",  targets: ["ObjectBox.xcframework"]
    ),
  ],
  targets: [

    /// MARK: - Binary dependencies
    .binaryTarget(
      name: "ObjectBoxGenerator",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v4.0.2-rc1/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "a2942a8bedb5790956e4961be773270cfcf02b6a277f3eae00477bd056cb0187"
    ),
    .binaryTarget(
      name: "ObjectBox.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v4.0.2-rc1/ObjectBox.xcframework.zip",
      checksum: "b369a4b4fc57c8f7c7620f275ed1b0f62970cf612e68f47382d44ce311d52c11"
    ),

    /// MARK: - Plugin implementations
    .plugin(
      name: "GeneratorCommand",
      capability: .command(
        intent: .custom(
          verb: "objectbox-generator",  // this is what the user uses
          description: "Does the ObjectBox Model generation, and we will add some more text here"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Generate source files in the package directory")
        ]
      ),
      dependencies: [
        .target(name: "ObjectBoxGenerator")
      ],
      path: "Plugins/GeneratorCommand"
    ),

  ]
)

