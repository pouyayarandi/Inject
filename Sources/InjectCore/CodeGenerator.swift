import Foundation
import SwiftSyntax
import SwiftParser

// Cache structure for storing parsed results
private struct FileCache: Codable {
    let lastModified: Date
    let bindings: [Binding]
    let injections: [InjectedDependency]
}

// Cache manager for handling file caching
private class CacheManager {
    private var cache: [String: FileCache] = [:]
    private let lock = NSLock()
    private let cacheFileURL: URL
    private var hasChanges = false
    
    init() {
        // Store cache in derived data directory
        let fileManager = FileManager.default
        let derivedDataURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.inject")
            .appendingPathComponent("cache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: derivedDataURL, withIntermediateDirectories: true)
        
        cacheFileURL = derivedDataURL.appendingPathComponent("inject.cache")
        loadCache()
    }
    
    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let decodedCache = try? JSONDecoder().decode([String: FileCache].self, from: data) else {
            return
        }
        cache = decodedCache
    }
    
    private func saveCache() {
        guard hasChanges else { return }
        
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheFileURL)
            hasChanges = false
        } catch {
            print("Failed to save cache: \(error)")
        }
    }
    
    func getCache(for filePath: String) -> FileCache? {
        lock.lock()
        defer { lock.unlock() }
        return cache[filePath]
    }
    
    func updateCache(for filePath: String, bindings: [Binding], injections: [InjectedDependency]) {
        lock.lock()
        defer { lock.unlock() }
        
        cache[filePath] = FileCache(
            lastModified: Date(),
            bindings: bindings,
            injections: injections
        )
        hasChanges = true
    }
    
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        hasChanges = true
    }
    
    func invalidateCache(for filePath: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: filePath)
        hasChanges = true
    }
    
    func flush() {
        lock.lock()
        defer { lock.unlock() }
        saveCache()
    }
}

/// Parse Swift source files and find bindings and injections
public func parseSourceFiles(in directories: [String]) throws -> (bindings: [Binding], injections: [InjectedDependency]) {
    let cacheManager = CacheManager()
    let fileManager = FileManager.default
    var allBindings: [Binding] = []
    var allInjections: [InjectedDependency] = []
    
    // Create a concurrent queue for parallel processing
    let queue = DispatchQueue(label: "com.inject.parser", attributes: .concurrent)
    let group = DispatchGroup()
    let lock = NSLock()
    
    for directory in directories {
        guard let enumerator = fileManager.enumerator(atPath: directory) else { continue }
        
        while let filePath = enumerator.nextObject() as? String {
            guard filePath.hasSuffix(".swift") else { continue }
            
            let fullPath = (directory as NSString).appendingPathComponent(filePath)
            
            // Check if file has been modified since last cache
            if let cache = cacheManager.getCache(for: fullPath),
               let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let modificationDate = attributes[.modificationDate] as? Date,
               modificationDate <= cache.lastModified {
                // Use cached results
                lock.lock()
                allBindings.append(contentsOf: cache.bindings)
                allInjections.append(contentsOf: cache.injections)
                lock.unlock()
                continue
            }
            
            group.enter()
            queue.async {
                defer { group.leave() }
                
                do {
                    let sourceFile = try String(contentsOfFile: fullPath, encoding: .utf8)
                    let syntax = Parser.parse(source: sourceFile)
                    let visitor = DependencyVisitor()
                    visitor.setFileName(fullPath)
                    visitor.walk(syntax)
                    
                    // Update cache
                    cacheManager.updateCache(for: fullPath, bindings: visitor.bindings, injections: visitor.injections)
                    
                    lock.lock()
                    allBindings.append(contentsOf: visitor.bindings)
                    allInjections.append(contentsOf: visitor.injections)
                    lock.unlock()
                } catch {
                    print("Error processing file \(fullPath): \(error)")
                }
            }
        }
    }
    
    group.wait()
    
    // Save cache after all files are processed
    cacheManager.flush()
    
    // Remove duplicates
    let bindings = Set<Binding>(allBindings)
    return (.init(bindings), allInjections)
}

/// Validate that all injected dependencies have a corresponding binding
/// and there is no duplicate binding for a specific type
public func validateDependencies(bindings: [Binding], injections: [InjectedDependency]) throws {
    let registeredTypes = Set(bindings.map { $0.type })
    var missingDependencies: [(type: String, location: SourceLocation)] = []
    
    for injection in injections {
        if !registeredTypes.contains(injection.type) {
            missingDependencies.append((injection.type, injection.location))
        }
    }

    if registeredTypes.count != bindings.count {
        // There is some duplicate bindings
        var message = "Duplicate @Bind found for the following types:\n"
        for type in registeredTypes {
            let bindings = bindings.filter({ $0.type == type })
            if bindings.count > 1 {
                message += "- \(type) is bound with multiple implementations:\n"
                for binding in bindings {
                    message += "  - \(binding.location)\n"
                }
            }
        }
        throw ValidationError(message: message)
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
public func generateContainerCode(bindings: [Binding], imports: [String], injections: [InjectedDependency]) -> String {
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
                code += "        registerSingleton(\(binding.type).self) { shared\(implementation) }\n"
            }
        } else {
            // Normal registration for non-singletons or singletons with a single type
            for binding in bindings {
                if binding.isSingleton {
                    code += "        registerSingleton(\(binding.type).self) { \(binding.implementation)() }\n"
                } else {
                    code += "        register(\(binding.type).self) { \(binding.implementation)() }\n"
                }
            }
        }
    }
    
    code += """
        }
    }
    
    """

    code += """
    
    #if DEBUG
    /// Resolves all dependencies injected in code to assert bindings
    /// Use it only for testing purposes
    extension AppContainer {
        func assertAllInjections() {

    """

    for injection in Set(injections.map(\.type)) {
        code += "       _ = AppContainer.shared.resolve(type: \(injection).self)\n"
    }

    code += """
        }
    }
    #endif
    
    """

    return code
} 
