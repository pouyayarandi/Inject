import Foundation

#if swift(<6.0)
// Swift 5 compatibility: Use DispatchQueue and @unchecked Sendable
public final class AppContainer: @unchecked Sendable {
    public static let shared = AppContainer()
    
    private let queue = DispatchQueue(label: "com.inject.container", attributes: .concurrent)
    private var instances: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    private var singletonTypes: Set<ObjectIdentifier> = []
    
    private init() {}
    
    public func resolve<T>(type: T.Type) -> T {
        let typeId = ObjectIdentifier(type)
        
        // Read access can be sync. Return T?
        let instance: T? = queue.sync {
            if singletonTypes.contains(typeId), let existingInstance = instances[typeId] as? T {
                return existingInstance
            }
            return nil
        }
        
        if let instance = instance {
            return instance
        }
        
        let factory = queue.sync { factories[typeId] }
        
        guard let factory = factory else {
            fatalError("No implementation found for type \(type)")
        }
        
        let newInstance = factory() as! T
        let shouldStore = queue.sync { singletonTypes.contains(typeId) }
        
        if shouldStore {
            queue.async(flags: .barrier) { [weak self] in
                if self?.instances[typeId] == nil {
                    self?.instances[typeId] = newInstance
                }
            }
        }
        
        return newInstance
    }
    
    public func register<T>(_ type: T.Type, isSingleton: Bool = false, factory: @escaping () -> T) {
        let typeId = ObjectIdentifier(type)
        queue.async(flags: .barrier) { [weak self] in
            self?.factories[typeId] = factory
            if isSingleton {
                self?.singletonTypes.insert(typeId)
            }
        }
    }
}

#else
// Swift 6 and later: Use @MainActor isolation
@MainActor // Isolate container operations to the main thread
public final class AppContainer { // No Sendable conformance needed explicitly due to @MainActor
    public static let shared = AppContainer() // Access must be from MainActor

    // Properties are protected by @MainActor isolation
    private var instances: [ObjectIdentifier: Any] = [:]
    private var factories: [ObjectIdentifier: @MainActor () -> Any] = [:] // Factory must be Sendable
    private var singletonTypes: Set<ObjectIdentifier> = []

    private init() {
        // Must be called from MainActor
    }

    // Resolve is synchronous when called from another @MainActor context (like @Inject)
    // Still requires T: Sendable because the stored instance might be used across actors later
    // TODO: T should be Sendable, currently ignored to suppress warnings
    public func resolve<T>(type: T.Type) -> T {
        let typeId = ObjectIdentifier(type)

        if singletonTypes.contains(typeId), let instance = instances[typeId] as? T {
            return instance
        }

        guard let factory = factories[typeId] else {
            fatalError("No implementation found for type \(type)")
        }

        let newInstance = factory() as! T // T is Sendable

        if singletonTypes.contains(typeId) {
             if instances[typeId] == nil {
                 instances[typeId] = newInstance
            }
        }

        return newInstance
    }

    // Register is synchronous when called from another @MainActor context
    // Factory must be @Sendable
    // TODO: T should be Sendable, currently ignored to suppress warnings
    public func register<T>(_ type: T.Type, isSingleton: Bool = false, factory: @escaping @MainActor () -> T) {
        let typeId = ObjectIdentifier(type)
        factories[typeId] = factory
        if isSingleton {
            singletonTypes.insert(typeId)
        }
    }
}

#endif 
