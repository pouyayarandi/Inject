import Foundation
import SwiftSyntax
import SwiftParser

/// Parse Swift source files and find bindings and injections
public func parseSourceFiles(in directories: [String]) throws -> (bindings: [Binding], injections: [InjectedDependency]) {
    let visitor = DependencyVisitor()
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

/// Validate that all injected dependencies have a corresponding binding
public func validateDependencies(bindings: [Binding], injections: [InjectedDependency]) throws {
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

/// Generate container code that registers all dependencies
public func generateContainerCode(bindings: [Binding], imports: [String]) -> String {
    var code = ""
    
    // Add custom imports
    for importStatement in imports {
        code += "import \(importStatement)\n"
    }
    
    // Add default imports
    code += """
    import Inject
    
    extension AppContainer {
        func registerDependencies() {
    
    """
    
    // Group bindings by implementation
    let bindingsByImplementation = Dictionary(grouping: bindings) { $0.implementation }
    
    for (implementation, bindings) in bindingsByImplementation {
        let isSingleton = bindings.first?.isSingleton ?? false
        
        if isSingleton && bindings.count > 1 {
            // For singletons bound to multiple types, create a shared factory function
            code += "        // Create shared singleton instance of \(implementation)\n"
            code += "        let shared\(implementation) = \(implementation)()\n"

            // Register all types with the shared instance
            for binding in bindings {
                code += "        register(\(binding.type).self, isSingleton: true) { shared\(implementation) }\n"
            }
        } else {
            // Normal registration for non-singletons or singletons with a single type
            for binding in bindings {
                code += "        register(\(binding.type).self, isSingleton: \(binding.isSingleton)) { \(binding.implementation)() }\n"
            }
        }
    }
    
    code += """
        }
    }
    """
    
    return code
} 