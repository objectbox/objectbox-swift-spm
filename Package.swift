// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ObjectBox",

  products: [
    .plugin(name: "BuildCommand", targets: ["BuildCommand"]),  // not functional, just a placeholder
    .plugin(name: "GeneratorCommand", targets: ["GeneratorCommand"]),
    .library(name: "ObjectBox", targets: ["ObjectBox"]),
    // .library(name: "ObjectBoxSyc", targets: ["ObjectBoxSync"]),

  ],
  targets: [

    /// MARK: - Binary dependencies
    .binaryTarget(
      name: "ObjectBoxGenerator",
      // path: "Resources/ObjectBoxGenerator.artifactbundle"
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v1.3.x/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "62d3e8d9e7141ef75462c8f8f08e6334def0b80f946053550ff7c6789c3187f9"
    ),
    .binaryTarget(
      name: "ObjectBox",
      //path: "../tmp/ObjectBox-xcframework-4.0.3.zip"
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v1.3.x/ObjectBox.xcframework.zip",
      checksum: "c501fd6f86950207913d0f7222feeaefd727711548da241e2508313b0a3a50ad"
    ),

    // .binaryTarget(
    //   name: "ObjectBoxSync",
    //   url:
    //     "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v1.3.x/ObjectBoxSync.xcframework.zip",
    //   checksum: "TODO"
    // ),

    /// MARK: - Plugin implementations

    // TODO, nothing functional atm, just a placeholder
    .plugin(
      name: "BuildCommand",
      capability: .buildTool(),
      path: "Plugins/BuildCommand"
    ),

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
