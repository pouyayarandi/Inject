import PackagePlugin
import Foundation

@main
struct InjectGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // Get the path to the code generator executable
        let injectPlugin = try context.tool(named: "InjectPlugin")
        
        // Create a directory for the generated files in the build directory
        let outputDir = context.pluginWorkDirectory
        try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
        
        // Output file path in the build directory
        let outputFilePath = outputDir.appending("Container+Generated.swift")
        
        // Get all Swift source files
        let sourceFiles = target.sourceModule?.sourceFiles.map(\.path) ?? []
        let sourceDirs = Set(sourceFiles.map { $0.removingLastComponent() })
        
        // Create the command
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.path,
                arguments: [
                    "--source-dirs", sourceDirs.map(\.string).joined(separator: ","),
                    "--output", outputFilePath.string
                ],
                inputFiles: sourceFiles,
                outputFiles: [outputFilePath]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension InjectGeneratorPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Get the path to the code generator executable
        let injectPlugin = try context.tool(named: "InjectPlugin")
        
        // Create a directory for the generated files in the build directory
        let outputDir = context.pluginWorkDirectory
        try FileManager.default.createDirectory(atPath: outputDir.string, withIntermediateDirectories: true)
        
        // Output file path in the build directory
        let outputFilePath = outputDir.appending("Container+Generated.swift")
        
        // Get all Swift source files
        let sourceFiles = target.inputFiles.filter { $0.type == .source && $0.path.extension == "swift" }
        let sourceDirs = Set(sourceFiles.map { $0.path.removingLastComponent() })
        
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.path,
                arguments: [
                    "--source-dirs", sourceDirs.map(\.string).joined(separator: ","),
                    "--output", outputFilePath.string
                ],
                inputFiles: sourceFiles.map(\.path),
                outputFiles: [outputFilePath]
            )
        ]
    }
}
#endif 
