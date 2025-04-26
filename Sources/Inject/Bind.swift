import Foundation

@attached(peer)
public macro Bind(_ types: Any.Type...) = #externalMacro(module: "InjectMacros", type: "BindMacro")

@attached(peer)
public macro Bind() = #externalMacro(module: "InjectMacros", type: "BindMacro")
