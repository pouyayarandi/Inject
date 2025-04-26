import Foundation
import SwiftSyntax
import SwiftParser

/// Visitor class for traversing Swift source code and finding bindings and injections
public class DependencyVisitor: SyntaxVisitor {
    public var bindings: [Binding] = []
    public var injections: [InjectedDependency] = []
    
    public init() {
        super.init(viewMode: .sourceAccurate)
    }
    
    // Helper function to convert SwiftSyntax.SourceLocation to our custom SourceLocation
    private func convertSourceLocation(_ location: SwiftSyntax.SourceLocation, fileName: String = "") -> SourceLocation {
        return SourceLocation(
            line: location.line,
            column: location.column,
            offset: location.offset,
            file: fileName
        )
    }
    
    // Helper method to process @Bind attribute for any declaration type
    private func processBindAttribute(name: TokenSyntax, attributes: AttributeListSyntax, node: SyntaxProtocol) {
        if let bindAttr = attributes.first(where: { attr in
            guard case let .attribute(attribute) = attr.trimmed else { return false }
            return attribute.attributeName.description == "Bind"
        }) {
            let implementation = name.text
            
            // Extract all types from @Bind
            var types: [String] = []
            if case let .attribute(attribute) = bindAttr,
               let arguments = attribute.arguments?.as(LabeledExprListSyntax.self) {
                if arguments.isEmpty {
                    // If no types provided, use the implementation type
                    types.append(implementation)
                } else {
                    // Process each type argument
                    for arg in arguments {
                        let typeText = arg.expression.trimmed.description.replacingOccurrences(of: ".self", with: "")
                        types.append(typeText)
                    }
                }
            } else {
                // Default to the implementation type if no arguments
                types.append(implementation)
            }
            
            // Check if @Singleton is present
            let isSingleton = attributes.contains(where: { attr in
                guard case let .attribute(attribute) = attr.trimmed else { return false }
                return attribute.attributeName.description == "Singleton"
            })
            
            // Create a binding for each type
            for type in types {
                let converter = SourceLocationConverter(fileName: "", tree: Syntax(node).root)
                let swiftLocation = node.startLocation(converter: converter)
                bindings.append(Binding(
                    type: type,
                    implementation: implementation,
                    location: convertSourceLocation(swiftLocation, fileName: ""),
                    isSingleton: isSingleton
                ))
            }
        }
    }
    
    override public func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        processBindAttribute(name: node.name, attributes: node.attributes, node: node)
        return .visitChildren
    }
    
    override public func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        processBindAttribute(name: node.name, attributes: node.attributes, node: node)
        return .visitChildren
    }
    
    override public func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        processBindAttribute(name: node.name, attributes: node.attributes, node: node)
        return .visitChildren
    }
    
    override public func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        processBindAttribute(name: node.name, attributes: node.attributes, node: node)
        return .visitChildren
    }
    
    override public func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.attributes.contains(where: { attr in
            guard case let .attribute(attribute) = attr.trimmed else { return false }
            return attribute.attributeName.description == "Inject"
        }) {
            guard let binding = node.bindings.first,
                  let type = binding.typeAnnotation?.type else {
                return .visitChildren
            }
            
            let converter = SourceLocationConverter(fileName: "", tree: node.root)
            let swiftLocation = node.startLocation(converter: converter)
            injections.append(InjectedDependency(
                type: type.description,
                location: convertSourceLocation(swiftLocation, fileName: "")
            ))
        }
        return .visitChildren
    }
} 