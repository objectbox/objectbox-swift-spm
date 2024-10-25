// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ObjectBox",

  products: [
    .plugin(name: "GeneratorCommand", targets: ["GeneratorCommand"]),
    .library(name: "ObjectBox", targets: ["ObjectBox"]),
  ],
  targets: [

    /// MARK: - Binary dependencies
    .binaryTarget(
      name: "ObjectBoxGenerator",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v1.3.x/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "62d3e8d9e7141ef75462c8f8f08e6334def0b80f946053550ff7c6789c3187f9"
    ),
    .binaryTarget(
      name: "ObjectBox",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v1.3.x/ObjectBox.xcframework.zip",
      checksum: "b680d60d598f818d5f077eebbe0584bd38b723c982133bc186ffe18bf6364eb2"
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
