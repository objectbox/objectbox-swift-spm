import Foundation
import PackagePlugin

// There are a few things to do
// - the stencil template file should be in the plugin directory, and be accessed from there
// - XCode way needs to adopt paths ... find the common path from the model files, and work there

@main
struct GeneratorCommand: CommandPlugin {

  func runGenerator(generator: PluginContext.Tool, args: [String]) {

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

    // keep for now as a reminder to check if we process args, or not
    let tool = try context.tool(named: "objectbox-generator")
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

    for target in targets {
      guard let target = target.sourceModule else { continue }

      let targetPath = target.directory
      print("Generating ObjectBox code for \(target.name) at \(targetPath)")

      let args: [String] = [
        "--sources", targetPath.string,
        "--model-json", targetPath.appending("ObjectBox-models.json").string,
        "--output", targetPath.appending("ObjectBox-generated").string,
        "--disableCache",
        "--verbose",
        "--no-statistics",
      ]

      runGenerator(generator: tool, args: args)

    }
  }
}

#if canImport(XcodeProjectPlugin)
  import XcodeProjectPlugin

  extension GeneratorCommand: XcodeCommandPlugin {

    func performCommand(context: XcodePluginContext, arguments: [String]) throws {

      // TODO , this is way more complex than the PackagePlugin version
      // XCode has no structure,
      // Probably just print a message to work with the cocoapod right now
      // but lets try and see how far we can come

      let generatorTool = try context.tool(named: "objectbox-generator")
      let generatorUrl = URL(fileURLWithPath: generatorTool.path.string)

      var argExtractor = ArgumentExtractor(arguments)
      let targetNames = argExtractor.extractOption(named: "target")

      if targetNames.count != 1 {
        Diagnostics.error(
          """
            \(targetNames.count) target names given: \(targetNames)
            Please select exact 1 target
          """)
      }

      let targetName = targetNames[0]

      var inputFiles: PackagePlugin.FileList?
      for target in context.xcodeProject.targets {
        if target.product?.name == targetName {
          Diagnostics.remark("Found target \(targetName)")
          inputFiles = target.inputFiles
        }
      }

      if inputFiles == nil {
        Diagnostics.warning("Target \(targetName) has not files")
        return
      }

      var sourcesArgs: [String] = []
      for inputFile in inputFiles! {
        //inputFile.path.string
        if inputFile.path.string.hasSuffix(".swift") {
          sourcesArgs.append("--sources")
          sourcesArgs.append(inputFile.path.string)
        }
      }

      if sourcesArgs.isEmpty {
        // TODO probably error
        Diagnostics.warning("No Sift files found in Target \(targetName) ")
        return
      }

      let targetPath = context.xcodeProject.directory

      let args: [String] =
        sourcesArgs + [
          "--model-json", targetPath.appending("ObjectBox-models.json").string,
          "--output", targetPath.appending("ObjectBox-generated").string,
          "--templates", targetPath.string,
          "--disableCache",
          "--verbose",
          "--no-statistics",
        ]

      runGenerator(generator: tool, args: args)

      // TODO , figgure out how to add the generated folder to xcode within here

    }

  }

#endif
