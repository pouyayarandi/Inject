// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@propertyWrapper
public final class Inject<T> {
    private var value: T?
    private let lock = NSRecursiveLock()
    
    public init() {}
    
    public var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            
            if let value = value {
                return value
            }
            let resolvedValue = AppContainer.shared.resolve(type: T.self)
            value = resolvedValue
            return resolvedValue
        }
    }
    
    /// Allows setting a mock value for testing purposes.
    /// This method should only be used in tests.
    public func setForTesting(_ newValue: T) {
        #if DEBUG
        lock.lock()
        defer { lock.unlock() }
        value = newValue
        #else
        assertionFailure("setForTesting can only be used in DEBUG configuration")
        #endif
    }
}
