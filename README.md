# The ObjectBox Swift Package

This Swift package contains the ObjectOox generator as a plugin and the ObjectBox library.

## Usage

Add you package dependency

### From a Swift package

Declare the package dependency

```swift
  .package(url: "https://github.com/objectbox/objectbox-swift-spm.git", branch: "main")
```

Then link your application with ObjectBox

```swift
  .executableTarget(
    name: "MyApp",
    dependencies: [
        .product(name: "ObjectBox.xcframework", package: "objectbox-swift-spm")
    ],
```

### For a XCode project

- Add a package dependency `"https://github.com/objectbox/objectbox-swift-spm.git"` for your project.
- Confirm to link your project against `ObjectBox.xcframework`

## Running the objectbox code generator

The plugin name name is `objectbox-generator`

The generator requires file write permissions into the project directory since it is generating files.

### Command line

To run the plugin from the command line:

```bash
swift package plugin --allow-writing-to-package-directory objectbox-generator
```

### XCode

Find the plugin menu entry for `ObjectBox` and run the `GeneratorCommand`.

You will be asked to select a target, select that one which contains your ObjectBox model.

## Known limitations

- The MacCatalyst build has not yet been integrated into Objectbox tests.
- For XCode project, the generated file `TargetProject/ObjectBox-generated/EntityInfo.generated.swift` needs to be added to XCode by hand.
- After changes on the ObjectBox models, the generator needs to be executed manually. This is due to the fact that only Generator commands are allowed to write to the package directory, and ObjectBox generated `ObjectBox-models.json` file needs to be added to git.
