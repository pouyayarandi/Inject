import Foundation
import SwiftSyntax

// Models for dependency information

/// Represents a location in source code
public struct SourceLocation: Hashable, CustomStringConvertible {
    public let line: Int
    public let column: Int
    public let offset: Int
    public let file: String
    
    public init(line: Int, column: Int, offset: Int, file: String) {
        self.line = line
        self.column = column
        self.offset = offset
        self.file = file
    }
    
    public var description: String {
        return "\(file):\(line):\(column)"
    }
}

/// Represents a binding between a type and its implementation
public struct Binding: Hashable {
    public let type: String
    public let implementation: String
    public let location: SourceLocation
    public let isSingleton: Bool
    
    public init(type: String, implementation: String, location: SourceLocation, isSingleton: Bool) {
        self.type = type
        self.implementation = implementation
        self.location = location
        self.isSingleton = isSingleton
    }
}

/// Represents a dependency that is injected into a class
public struct InjectedDependency {
    public let type: String
    public let location: SourceLocation
    
    public init(type: String, location: SourceLocation) {
        self.type = type
        self.location = location
    }
}

/// Error thrown during validation
public struct ValidationError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
    
    public init(message: String) {
        self.message = message
    }
} 