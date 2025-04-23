import Foundation

@attached(peer)
public macro Bind<T>(_ type: T.Type = Void.self) = #externalMacro(module: "InjectMacros", type: "BindMacro")
