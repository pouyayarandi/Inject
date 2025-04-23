import Foundation

public final class AppContainer {
    public static let shared = AppContainer()
    
    private var instances: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: () -> Any] = [:] // Will be populated by code generation
    private var singletonTypes: Set<ObjectIdentifier> = [] // Track which types are singletons
    
    private init() {}
    
    public func resolve<T>(type: T.Type) -> T {
        let typeId = ObjectIdentifier(type)
        
        // Return existing instance if it's a singleton and already created
        if singletonTypes.contains(typeId), let instance = instances[typeId] as? T {
            return instance
        }
        
        guard let factory = factories[typeId] else {
            fatalError("No implementation found for type \(type)")
        }
        
        let instance = factory() as! T
        
        // Only store instance if it's a singleton
        if singletonTypes.contains(typeId) {
            instances[typeId] = instance
        }
        
        return instance
    }
}

extension AppContainer {
    public func register<T>(_ type: T.Type, isSingleton: Bool = false, factory: @escaping () -> T) {
        factories[ObjectIdentifier(type)] = factory
        if isSingleton {
            singletonTypes.insert(ObjectIdentifier(type))
        }
    }
} 
