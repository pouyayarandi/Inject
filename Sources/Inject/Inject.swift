// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

#if swift(<6.0)
// Swift 5 compatibility: No Sendable constraint, synchronous access assumes caller context or handles thread safety via lock.
@propertyWrapper
public final class Inject<T> {
    private var value: T?
    private let lock = NSRecursiveLock() // Lock needed for thread-safe lazy resolution
    
    public var wrappedValue: T {
        lock.lock(); defer { lock.unlock() }
        
        if let value = value {
            return value
        }
        
        let resolvedValue = AppContainer.shared.resolve(type: T.self)
        value = resolvedValue
        return resolvedValue
    }
    
    public init() {}
    
    /// Allows setting a mock value for testing purposes.
    /// This method should only be used in tests.
    public func setForTesting(_ newValue: T) {
        // Ensure thread safety when setting mock value
        lock.lock(); defer { lock.unlock() }
        #if DEBUG
        value = newValue
        #else
        // Provide a way to indicate misuse in release builds if necessary
        assertionFailure("setForTesting should only be used in DEBUG configuration")
        #endif
    }
}
#else
// Swift 6+: T must be Sendable, property wrapper isolated to MainActor.
@propertyWrapper
@MainActor // Ensures wrappedValue access is on MainActor for sync call to container.
public final class Inject<T> {
    private var value: T?
    // No explicit lock needed due to @MainActor isolation for access.
    
    public var wrappedValue: T {
        // Access is guaranteed to be on MainActor.
        if let value = value {
            return value
        }
        
        // Synchronous call is safe because both Inject and AppContainer are @MainActor isolated.
        // T is constrained to Sendable as required by the Swift 6+ AppContainer.resolve.
        let resolvedValue = AppContainer.shared.resolve(type: T.self)
        value = resolvedValue
        return resolvedValue
    }
    
    public init() {}
    
    /// Allows setting a mock value for testing purposes.
    /// Must be called from MainActor.
    public func setForTesting(_ newValue: T) {
        #if DEBUG
        value = newValue
        #else
        // Provide a way to indicate misuse in release builds if necessary
        assertionFailure("setForTesting should only be used in DEBUG configuration")
        #endif
    }
}
#endif
