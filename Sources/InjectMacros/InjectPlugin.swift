import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros

@main
struct InjectPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        BindMacro.self,
        SingletonMacro.self
    ]
}

public struct BindMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro doesn't generate any code
        // The code generation happens in the plugin
        return []
    }
}

public struct SingletonMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This macro doesn't generate any code
        // The code generation happens in the plugin
        return []
    }
}
