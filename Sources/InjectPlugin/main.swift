import Foundation
import ArgumentParser
import InjectCore

// Command line interface
struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inject-generator",
        abstract: "Generates dependency container code"
    )
    
    @Option(name: .long, help: "Comma-separated list of source directories")
    var sourceDirs: String
    
    @Option(name: .long, help: "Output file path")
    var output: String
    
    @Option(name: .long, help: "Comma-separated list of imports")
    var imports: String = ""
    
    func run() throws {
        let directories = sourceDirs.split(separator: ",").map(String.init)
        let importStatements = imports.isEmpty ? [] : imports.split(separator: ",").map(String.init)

        let (bindings, injections) = try parseSourceFiles(in: directories)

        // Validate all dependencies are properly bound
        try validateDependencies(bindings: bindings, injections: injections)

        let generatedCode = generateContainerCode(
            bindings: bindings,
            imports: importStatements,
            injections: injections
        )

        try generatedCode.write(toFile: output, atomically: true, encoding: .utf8)
    }
}

GenerateCommand.main() 
