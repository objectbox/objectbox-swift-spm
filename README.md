# The ObjectBox Swift Package

This Swift package contains the ObjectOox generator as a plugin and the ObjectBox library.

## Usage

Declare the package dependency

```swift
  .package(url: "https://github.com/objectbox/objectbox-swift-spm.git", branch: "main")
```

Then link your application with ObjectBox

```swift
  .executableTarget(
    name: "CoolApp",
    dependencies: [
        .product(name: "ObjectBox", package: "objectbox-swift-spm")
    ],
```

## Running the objectbox code generator

The plugin name name is `objectbox-generator`

The generator requires file write permissions into the project directory since it is generating files.

### Command line

To run the plugin from the command line:

```bash
swift package plugin --allow-writing-to-package-directory objectbox-generator
```

### XCode, opening a Swift package

Find the plugin menu entry for `ObjectBox` and run the `GeneratorCommand`.

If you have multiple targets, select the one for which you want to generate the code.

### XCode, classic .xcodeproj

As for now, we still recommend to use the existing Cocoapod.

However, if you want, you can still add `objectbox-swift-spm` as a package dependency
and run the generator command. But please be aware that this is not supported yet.

TODO: add note about the XCFramework

(TODO: Note to myself: Align cocoapod way and generator way to produce the same files)
