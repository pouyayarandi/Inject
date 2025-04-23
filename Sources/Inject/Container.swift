import Foundation

public final class AppContainer {
    public static let shared = AppContainer()
    
    private var instances: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: () -> Any] = [:] // Will be populated by code generation
    
    private init() {}
    
    public func resolve<T>(type: T.Type) -> T {
        if let instance = instances[ObjectIdentifier(type)] as? T {
            return instance
        }
        
        guard let factory = factories[ObjectIdentifier(type)] else {
            fatalError("No implementation found for type \(type)")
        }
        
        let instance = factory() as! T
        instances[ObjectIdentifier(type)] = instance
        return instance
    }
}

extension AppContainer {
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        factories[ObjectIdentifier(type)] = factory
    }
} 
