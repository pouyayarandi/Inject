import Foundation

/// A utility class for injecting test dependencies into objects
public class TestInjector {
    private let mirror: Mirror

    /// Initialize with the system under test
    /// - Parameter sut: The object that contains `Inject` properties
    public init(_ sut: Any) {
        mirror = .init(reflecting: sut)
    }

    private struct InjectableNotFound<T>: Error, CustomStringConvertible {
        var description: String {
            "Injectable not found for type: \(String(describing: T.self))"
        }
    }

    private func injectables<T>(of type: T.Type, key: String?) throws -> [Inject<T>] {
        let injectables: [Inject<T>] = mirror.children.compactMap {
            if let key, $0.label != "_\(key)" { return nil }
            return $0.value as? Inject<T>
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
    public func inject<T>(_ value: T, as type: T.Type = T.self, key: String? = nil) throws -> Self {
        try injectables(of: T.self, key: key).forEach {
            $0.setForTesting(value)
        }
        return self
    }
}
