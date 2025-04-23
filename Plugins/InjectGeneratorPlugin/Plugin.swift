import PackagePlugin
import Foundation

private func readIncludefile(workingDirectory: Path) throws -> [String] {
    let includefilePath = workingDirectory.appending(".inject").appending("Includefile")
    guard let content = try? String(contentsOfFile: includefilePath.string, encoding: .utf8) else {
        return []
    }
    return content.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

private func readImportfile(workingDirectory: Path) throws -> [String] {
    let importfilePath = workingDirectory.appending(".inject").appending("Importfile")
    guard let content = try? String(contentsOfFile: importfilePath.string, encoding: .utf8) else {
        return []
    }
    return content.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

private func findSwiftFiles(in directory: Path) throws -> [Path] {
    let fileManager = FileManager.default
    var swiftFiles: [Path] = []
    
    if let enumerator = fileManager.enumerator(atPath: directory.string) {
        while let filePath = enumerator.nextObject() as? String {
            if filePath.hasSuffix(".swift") {
                swiftFiles.append(directory.appending(filePath))
            }
        }
    }
    
    return swiftFiles
}

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
        
        // Get target source files
        var sourceFiles = target.sourceModule?.sourceFiles.map(\.path) ?? []
        
        // Read paths from Includefile and append additional source files
        let includePaths = try readIncludefile(workingDirectory: target.directory)
        for relativePath in includePaths {
            let absolutePath = target.directory.appending(relativePath)
            sourceFiles.append(contentsOf: try findSwiftFiles(in: absolutePath))
        }
        
        // Read imports from Importfile
        let imports = try readImportfile(workingDirectory: target.directory)
        
        let sourceDirs = Set(sourceFiles.map { $0.removingLastComponent() })
        
        // Create the command
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.path,
                arguments: [
                    "--source-dirs", sourceDirs.map(\.string).joined(separator: ","),
                    "--output", outputFilePath.string,
                    "--imports", imports.joined(separator: ",")
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
        
        // Get target source files
        var sourceFiles = target.inputFiles
            .filter { $0.type == .source && $0.path.extension == "swift" }
            .map(\.path)
        
        // Read paths from Injectfile and append additional source files
        let includePaths = try readIncludefile(workingDirectory: context.xcodeProject.directory)
        for relativePath in includePaths {
            let absolutePath = context.xcodeProject.directory.appending(relativePath)
            sourceFiles.append(contentsOf: try findSwiftFiles(in: absolutePath))
        }
        
        // Read imports from Importfile
        let imports = try readImportfile(workingDirectory: context.xcodeProject.directory)
        
        let sourceDirs = Set(sourceFiles.map { $0.removingLastComponent() })
        
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.path,
                arguments: [
                    "--source-dirs", sourceDirs.map(\.string).joined(separator: ","),
                    "--output", outputFilePath.string,
                    "--imports", imports.joined(separator: ",")
                ],
                inputFiles: sourceFiles,
                outputFiles: [outputFilePath]
            )
        ]
    }
}
#endif 
