import Foundation

/// A utility for injecting test dependencies into objects
@propertyWrapper
public struct TestInjector<T> {
    public init(_ wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    private var mirror: Mirror {
        Mirror(reflecting: wrappedValue)
    }

    private struct InjectableNotFound<I>: Error, CustomStringConvertible {
        var description: String {
            "Injectable not found for type: \(String(describing: I.self))"
        }
    }

    private func injectables<I>(of type: I.Type, key: String?) throws -> [Inject<I>] {
        let injectables: [Inject<I>] = mirror.children.compactMap {
            if let key, $0.label != "_\(key)" { return nil }
            return $0.value as? Inject<I>
        }

        if injectables.isEmpty {
            throw InjectableNotFound<T>()
        }

        return injectables
    }

    /// Injects a test value into all matching injectable properties
    /// - Parameters:
    ///   - value: The test value to inject
    ///   - type: The type of the value, inferred by default
    ///   - key: Optional key to target a specific property
    /// - Returns: Self for chaining multiple injections
    /// - Throws: InjectableNotFound if no matching properties are found
    #if swift(>=6.0)
    @MainActor
    #endif
    @discardableResult
    public func inject<I>(_ value: I, as type: I.Type = I.self, key: String? = nil) throws -> Self {
        try injectables(of: I.self, key: key).forEach {
            $0.setForTesting(value)
        }
        return self
    }

    public var wrappedValue: T

    public var projectedValue: TestInjector<T> {
        self
    }
}
