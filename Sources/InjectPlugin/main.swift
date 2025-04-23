import Foundation
import SwiftSyntax
import SwiftParser
import ArgumentParser

// Model to store binding information
struct Binding {
    let type: String
    let implementation: String
    let location: SourceLocation
    let isSingleton: Bool
}

struct InjectedDependency {
    let type: String
    let location: SourceLocation
}

class DependencyVisitor: SyntaxVisitor {
    var bindings: [Binding] = []
    var injections: [InjectedDependency] = []
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if let bindAttr = node.attributes.first(where: { attr in
            guard case let .attribute(attribute) = attr.trimmed else { return false }
            return attribute.attributeName.description == "Bind"
        }) {
            let implementation = node.name.text
            var type = implementation
            
            // Check if a specific type is provided in @Bind
            if case let .attribute(attribute) = bindAttr,
               let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
               let firstArg = arguments.first {
                type = firstArg.expression.description.replacingOccurrences(of: ".self", with: "")
            }
            
            // Check if @Singleton is present
            let isSingleton = node.attributes.contains(where: { attr in
                guard case let .attribute(attribute) = attr.trimmed else { return false }
                return attribute.attributeName.description == "Singleton"
            })
            
            bindings.append(Binding(
                type: type,
                implementation: implementation,
                location: node.startLocation(converter: SourceLocationConverter(fileName: "", tree: node.root)),
                isSingleton: isSingleton
            ))
        }
        return .visitChildren
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.attributes.contains(where: { attr in
            guard case let .attribute(attribute) = attr.trimmed else { return false }
            return attribute.attributeName.description == "Inject"
        }) {
            guard let binding = node.bindings.first,
                  let type = binding.typeAnnotation?.type else {
                return .visitChildren
            }
            
            injections.append(InjectedDependency(
                type: type.description,
                location: node.startLocation(converter: SourceLocationConverter(fileName: "", tree: node.root))
            ))
        }
        return .visitChildren
    }
}

// Parse source files
func parseSourceFiles(in directories: [String]) throws -> (bindings: [Binding], injections: [InjectedDependency]) {
    let visitor = DependencyVisitor(viewMode: .sourceAccurate)
    let fileManager = FileManager.default
    
    for directory in directories {
        guard let enumerator = fileManager.enumerator(atPath: directory) else { continue }
        
        while let filePath = enumerator.nextObject() as? String {
            guard filePath.hasSuffix(".swift") else { continue }
            
            let fullPath = (directory as NSString).appendingPathComponent(filePath)
            let sourceFile = try String(contentsOfFile: fullPath, encoding: .utf8)
            let syntax = Parser.parse(source: sourceFile)
            
            visitor.walk(syntax)
        }
    }
    
    return (visitor.bindings, visitor.injections)
}

// Validate dependencies
func validateDependencies(bindings: [Binding], injections: [InjectedDependency]) throws {
    let registeredTypes = Set(bindings.map { $0.type })
    var missingDependencies: [(type: String, location: SourceLocation)] = []
    
    for injection in injections {
        if !registeredTypes.contains(injection.type) {
            missingDependencies.append((injection.type, injection.location))
        }
    }

    if !missingDependencies.isEmpty {
        var error = "Missing @Bind implementations for the following dependencies:\n"
        for missing in missingDependencies {
            error += "- \(missing.type) (used at \(missing.location))\n"
        }
        throw ValidationError(message: error)
    }
}

struct ValidationError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

// Generate container code
func generateContainerCode(bindings: [Binding]) -> String {
    var code = """
    import Inject
    
    extension AppContainer {
        func registerDependencies() {
    
    """
    
    for binding in bindings {
        code += "        register(\(binding.type).self, isSingleton: \(binding.isSingleton)) { \(binding.implementation)() }\n"
    }
    
    code += """
        }
    }
    """
    
    return code
}

// Command line interface
struct GenerateCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "inject-generator",
        abstract: "Generates dependency container code"
    )
    
    @Option(name: .long, help: "Comma-separated list of source directories")
    var sourceDirs: String
    
    @Option(name: .long, help: "Output file path")
    var output: String
    
    func run() throws {
        let directories = sourceDirs.split(separator: ",").map(String.init)

        let (bindings, injections) = try parseSourceFiles(in: directories)

        // Validate all dependencies are properly bound
        try validateDependencies(bindings: bindings, injections: injections)

        let generatedCode = generateContainerCode(bindings: bindings)
        try generatedCode.write(toFile: output, atomically: true, encoding: .utf8)
    }
}

GenerateCommand.main() 
