
import PackagePlugin
import Foundation

@main
struct BuildCommand: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Example command: Print a message during the build process

        print("Running ObsBuildPlugin, target name: \(target.name)")
        print("Running ObsBuildPlugin, cwd: \(context.pluginWorkDirectory)")

        return [
            .prebuildCommand(
                displayName: "Running ObsPlugin",
                //executable: try context.tool(named: "bash").path,
                executable: Path("/bin/bash"),
                arguments: [ "-c", "echo Hello from ObsPlugin!!!!!!!!!!!!! > \(context.pluginWorkDirectory)/output.txt" ],
                outputFilesDirectory: context.pluginWorkDirectory
            )
        ]
    }
}
