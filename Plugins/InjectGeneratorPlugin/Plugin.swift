import PackagePlugin
import Foundation

private func readIncludefile(workingDirectory: URL) throws -> [String] {
    let includefileURL = workingDirectory.appendingPathComponent(".inject").appendingPathComponent("Includefile")
    guard let content = try? String(contentsOf: includefileURL, encoding: .utf8) else {
        return []
    }
    return content.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

private func readImportfile(workingDirectory: URL) throws -> [String] {
    let importfileURL = workingDirectory.appendingPathComponent(".inject").appendingPathComponent("Importfile")
    guard let content = try? String(contentsOf: importfileURL, encoding: .utf8) else {
        return []
    }
    return content.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

private func findSwiftFiles(in directory: URL) throws -> [URL] {
    let fileManager = FileManager.default
    var swiftFiles: [URL] = []
    
    if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                swiftFiles.append(fileURL)
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
        let outputDirURL = context.pluginWorkDirectoryURL
        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
        
        // Output file path in the build directory
        let outputFileURL = outputDirURL.appendingPathComponent("Container+Generated.swift")
        
        // Get target source files as URLs
        var sourceFileURLs = target.sourceModule?.sourceFiles.map(\.url) ?? []
        
        // Read paths from Includefile and append additional source files
        let targetDirectoryURL = URL(fileURLWithPath: target.directory.string)
        let includePaths = try readIncludefile(workingDirectory: targetDirectoryURL)
        for relativePath in includePaths {
            let absoluteURL = targetDirectoryURL.appendingPathComponent(relativePath)
            sourceFileURLs.append(contentsOf: try findSwiftFiles(in: absoluteURL))
        }
        
        // Read imports from Importfile
        let imports = try readImportfile(workingDirectory: targetDirectoryURL)
        
        let sourceDirURLs = Set(sourceFileURLs.map { $0.deletingLastPathComponent() })
        
        // Create the command using URLs
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.url, // Use URL
                arguments: [
                    "--source-dirs", sourceDirURLs.map(\.path).joined(separator: ","),
                    "--output", outputFileURL.path, // Use URL path string for argument
                    "--imports", imports.joined(separator: ",")
                ],
                inputFiles: sourceFileURLs, // Use [URL]
                outputFiles: [outputFileURL] // Use [URL]
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
        let outputDirURL = context.pluginWorkDirectoryURL
        try FileManager.default.createDirectory(at: outputDirURL, withIntermediateDirectories: true)
        
        // Output file path in the build directory
        let outputFileURL = outputDirURL.appendingPathComponent("Container+Generated.swift")
        
        // Get target source files as URLs
        var sourceFileURLs = target.inputFiles
            .filter { $0.type == .source && $0.url.pathExtension == "swift" }
            .map(\.url)
        
        // Read paths from Injectfile and append additional source files
        let projectDirectoryURL = context.xcodeProject.directoryURL
        let includePaths = try readIncludefile(workingDirectory: projectDirectoryURL)
        for relativePath in includePaths {
            let absoluteURL = projectDirectoryURL.appendingPathComponent(relativePath)
            sourceFileURLs.append(contentsOf: try findSwiftFiles(in: absoluteURL))
        }
        
        // Read imports from Importfile
        let imports = try readImportfile(workingDirectory: projectDirectoryURL)
        
        let sourceDirURLs = Set(sourceFileURLs.map { $0.deletingLastPathComponent() })
        
        // Create the command using URLs
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.url, // Use URL
                arguments: [
                    "--source-dirs", sourceDirURLs.map(\.path).joined(separator: ","),
                    "--output", outputFileURL.path, // Use URL path string for argument
                    "--imports", imports.joined(separator: ",")
                ],
                inputFiles: sourceFileURLs, // Use [URL]
                outputFiles: [outputFileURL] // Use [URL]
            )
        ]
    }
}
#endif 
