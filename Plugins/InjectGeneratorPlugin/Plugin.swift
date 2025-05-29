import PackagePlugin
import Foundation

private func readIncludefile(workingDirectory: URL) -> [String] {
    let includefileURL = workingDirectory
        .appendingPathComponent(".inject")
        .appendingPathComponent("Includefile")

    guard let content = try? String(contentsOf: includefileURL, encoding: .utf8) else {
        return []
    }

    return content.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

private func readImportfile(workingDirectory: URL) -> [String] {
    let importfileURL = workingDirectory
        .appendingPathComponent(".inject")
        .appendingPathComponent("Importfile")

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
    
    if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .modificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
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
        var sourceFileURLs = target.sourceModule?.sourceFiles
            .filter { $0.type == .source && $0.url.pathExtension == "swift" }
            .map(\.url) ?? []
        
        // Read paths from Includefile and append additional source files
        let targetDirectoryURL = URL(fileURLWithPath: target.directory.string)
        let includePaths = readIncludefile(workingDirectory: targetDirectoryURL)
        for relativePath in includePaths {
            let absoluteURL = targetDirectoryURL.appendingPathComponent(relativePath)
            sourceFileURLs.append(contentsOf: try findSwiftFiles(in: absoluteURL))
        }
        
        // Read imports from Importfile
        let imports = readImportfile(workingDirectory: targetDirectoryURL)
        
        // Get unique source directories
        let sourceDirURLs = Set(sourceFileURLs.map { $0.deletingLastPathComponent() })
        
        // Build the arguments dynamically
        var arguments: [String] = [
            "--source-dirs", sourceDirURLs.map(\.path).joined(separator: ","),
            "--output", outputFileURL.path
        ]
        
        // Only add the imports flag if there are actually imports
        if !imports.isEmpty {
            arguments.append("--imports")
            arguments.append(imports.joined(separator: ","))
        }
        
        // Create the command using URLs
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.url,
                arguments: arguments,
                inputFiles: sourceFileURLs,
                outputFiles: [outputFileURL]
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
        
        // Read paths from Includefile and append additional source files
        let projectDirectoryURL = context.xcodeProject.directoryURL
        let includePaths = readIncludefile(workingDirectory: projectDirectoryURL)
        for relativePath in includePaths {
            let absoluteURL = projectDirectoryURL.appendingPathComponent(relativePath)
            sourceFileURLs.append(contentsOf: try findSwiftFiles(in: absoluteURL))
        }
        
        // Read imports from Importfile
        let imports = readImportfile(workingDirectory: projectDirectoryURL)
        
        // Get unique source directories
        let sourceDirURLs = Set(sourceFileURLs.map { $0.deletingLastPathComponent() })
        
        // Build the arguments dynamically
        var arguments: [String] = [
            "--source-dirs", sourceDirURLs.map(\.path).joined(separator: ","),
            "--output", outputFileURL.path
        ]
        
        // Only add the imports flag if there are actually imports
        if !imports.isEmpty {
            arguments.append("--imports")
            arguments.append(imports.joined(separator: ","))
        }
        
        // Create the command using URLs
        return [
            .buildCommand(
                displayName: "Generating Dependency Container",
                executable: injectPlugin.url,
                arguments: arguments,
                inputFiles: sourceFileURLs,
                outputFiles: [outputFileURL]
            )
        ]
    }
}
#endif 
