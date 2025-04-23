// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@propertyWrapper
public final class Inject<T> {
    private var value: T?
    
    public init() {}
    
    public var wrappedValue: T {
        get {
            if let value = value {
                return value
            }
            let resolvedValue = AppContainer.shared.resolve(type: T.self)
            value = resolvedValue
            return resolvedValue
        }
    }
}
