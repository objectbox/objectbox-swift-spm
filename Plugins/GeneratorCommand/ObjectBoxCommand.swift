//
// Copyright 2024 ObjectBox Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import PackagePlugin

// There are a few things to do
// - the stencil template file should be in the plugin directory, and be accessed from there

/// This is used when the command plugin is used from a Swift package
/// (so when running via the swift package plugin command).
///
/// Also see the ``XcodeCommandPlugin`` extension below.
@main
struct GeneratorCommand: CommandPlugin {

  // Path should match with CocoaPods setup for easy migration
  private func buildModelJsonFilePath(targetName: String) -> String {
    return "model-\(targetName).json"
  }

  // Path should match with CocoaPods setup for easy migration
  private func buildEntityInfoFilePath(targetName: String) -> String {
    return "generated/EntityInfo-\(targetName).generated.swift"
  }

  // Removes the `--target` option and its value from the arguments array
  // This is needed because the `--target` option is not recognized by the Sourcery executable
  private func removeTargetNameFromArgs(_ args: [String]) -> [String] {
    var filteredArgs = args
    if let targetIndex = filteredArgs.firstIndex(of: "--target") {
      // Remove --target and the following value (target name)
      filteredArgs.remove(at: targetIndex)
      if targetIndex < filteredArgs.count {
        filteredArgs.remove(at: targetIndex)
      }
    }
    return filteredArgs
  }

  private func runGenerator(
    generator: PluginContext.Tool, targetPath: Path, codeFilePath: String, modelFilePath: String,
    args: [String] = []
  ) {
    let modelFileTargetPath = targetPath.appending(modelFilePath).string
    let codeFileTargetPath = targetPath.appending(codeFilePath).string

    // The generator does not support the --target argument and would error, remove it
    let filteredArgs = removeTargetNameFromArgs(args)

    // Specify --sources for Xcode project setup as well, Sourcery does not seem able to detect Xcode project
    let args: [String] =
      [
        "--sources", targetPath.string,
        "--model-json", modelFileTargetPath,
        "--output", codeFileTargetPath,
        "--disableCache",
        "--verbose",
      ] + filteredArgs

    runGenerator(generator: generator, args: args)
  }

  private func runGenerator(generator: PluginContext.Tool, args: [String]) {

    let generatorUrl = URL(fileURLWithPath: generator.path.string)

    let environment: [String: String] = [
      "IN_PROCESS_SOURCEKIT": "1"
    ]

    let process = Process()
    process.executableURL = generatorUrl
    process.arguments = args
    process.environment = environment

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
      try process.run()
      process.waitUntilExit()

      let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
      let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

      if let output = String(data: outputData, encoding: .utf8) {
        print("\(output)")
      }

      if let errorOutput = String(data: errorData, encoding: .utf8) {
        print("\(errorOutput)")
      }

      let status = process.terminationStatus

      if status != 0 {
        print(
          "🛑 The plugin execution failed with reason: \(process.terminationReason.rawValue) and status: \(process.terminationStatus) "
        )
      } else {
        print("🟩 The plugin execution finished.")
      }

    } catch {
      print("Failed to run process: \(error)")
    }

  }

  func performCommand(context: PluginContext, arguments: [String]) throws {

    // keep for now as a reminder to check if args are processed, or not
    let tool = try context.tool(named: "objectbox-generator")
    print("Processing arguments: \(arguments)")
    if arguments.count == 1 {
      if arguments[0] == "context" {
        dump(context)
      } else if arguments[0] == "--help" {
        runGenerator(generator: tool, args: ["--help"])
      }
      return
    }

    var argExtractor = ArgumentExtractor(arguments)
    let targetNames = argExtractor.extractOption(named: "target")
    let targets =
      targetNames.isEmpty
      ? context.package.targets
      : try context.package.targets(named: targetNames)

    // Since the generator generates code even for targets that have no ObjectBox annotations at all,
    // restrict the target to not generate code for targets like tests ...
    if targets.count > 1 {
      let availableTargetNames = targets.map { $0.name }.joined(separator: ", ")
      Diagnostics.error(
        "Multiple targets found\nPlease select specify one target by using the `--target <name>` option\nAvailable target names: \(availableTargetNames)"
      )
      return
    } else if targets.isEmpty {
      Diagnostics.error("No target found")
      return
    }

    // This processes all targets, but above code ensures there is only one
    for target in targets {
      guard let target = target.sourceModule else { continue }

      let targetPath = target.directory
      print("Generating ObjectBox code for \(target.name) at \(targetPath)")
      let codeFilePath = buildEntityInfoFilePath(targetName: target.name)
      let modelFilePath = buildModelJsonFilePath(targetName: target.name)
      runGenerator(
        generator: tool, targetPath: targetPath, codeFilePath: codeFilePath,
        modelFilePath: modelFilePath, args: arguments)
    }
  }
}

#if canImport(XcodeProjectPlugin)
  import XcodeProjectPlugin

  /// This is used when the command plugin is used from an Xcode project
  extension GeneratorCommand: XcodeCommandPlugin {

    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
      let tool = try context.tool(named: "objectbox-generator")

      var argExtractor = ArgumentExtractor(arguments)
      let targetNames = argExtractor.extractOption(named: "target")

      if targetNames.count != 1 {
        Diagnostics.error(
          """
            \(targetNames.count) target names given: \(targetNames)
            Please select exactly 1 target
          """)
        return
      }

      let targetName = targetNames[0]

      let targetPath = context.xcodeProject.directory
      let codeFilePath = buildEntityInfoFilePath(targetName: targetName)
      let modelFilePath = buildModelJsonFilePath(targetName: targetName)

      // Note: not finding source files via context.xcodeProject.targets[0].inputFiles as for some projects not all
      // files appear to exist there (possibly related to "buildable folders"), just pass the target directory to
      // the generator and let it find source files.
      runGenerator(
        generator: tool, targetPath: targetPath, codeFilePath: codeFilePath,
        modelFilePath: modelFilePath, args: arguments)

      // TODO Add the generated files to the Xcode project
      Diagnostics.remark(
        "！ Add the generated source file in '\(codeFilePath)' to the project and version control\n"
      )
      Diagnostics.remark(
        "！ Add the generated model file in '\(modelFilePath)' to version control, this is important for ObjectBox model generation\n"
      )

    }

  }

#endif
