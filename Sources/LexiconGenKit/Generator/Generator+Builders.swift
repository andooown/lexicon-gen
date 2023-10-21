import SwiftSyntax
import SwiftSyntaxBuilder

public extension Generator {
    @CodeBlockItemListBuilder
    static func namespaces(_ namespaces: [SwiftNamespaceDefinition]) throws -> CodeBlockItemListSyntax {
        for namespace in namespaces {
            if namespace.parent.isEmpty {
                try EnumDeclSyntax("public enum \(raw: namespace.name)") {}
            } else {
                try ExtensionDeclSyntax("public extension \(raw: namespace.parent)") {
                    try EnumDeclSyntax("enum \(raw: namespace.name)") {}
                }
            }
        }
    }
}
