import Foundation

@attached(peer)
public macro Bind() = #externalMacro(module: "InjectMacros", type: "BindMacro")

@attached(peer)
public macro Bind<T>(_ type: T.Type) = #externalMacro(module: "InjectMacros", type: "BindMacro") 