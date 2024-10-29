// swift-tools-version: 5.10
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
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/SPM-preview1/ObjectBoxGenerator.artifactbundle.zip",
      checksum: "62d3e8d9e7141ef75462c8f8f08e6334def0b80f946053550ff7c6789c3187f9"
    ),
    .binaryTarget(
      name: "ObjectBox.xcframework",
      url:
        "https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/SPM-preview1/ObjectBox.xcframework.zip",
      checksum: "3222f5d3eec6f91a1d47f3a7acfec47c99bd7b2eeec27948fddd58bb8a9dd18e"
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

// TODO, we need to be able to switch between CI and release in the URL, but keep the checksum the same
// additionally, having an option for local development could also be handy
// see if this, or any other way could be used ...
// enum BinarySource {
//     case local, staging, release

//     init() {
//         if getenv("OBX_SPM_LOCAL_BINARIES") != nil {
//             self = .local
//         } else if getenv("OBX_SPM_STAGING_BINARIES") != nil  {
//             self = .staging
//         } else {
//             self = .release
//         }
//     }
// }

