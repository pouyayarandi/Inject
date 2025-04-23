import Foundation

@attached(peer)
public macro Singleton() = #externalMacro(module: "InjectMacros", type: "SingletonMacro") 
