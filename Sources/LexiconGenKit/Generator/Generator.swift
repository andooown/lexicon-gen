import SwiftSyntax
import SwiftSyntaxBuilder

public struct Generator {
    private let context: GenerateContext

    public init(context: GenerateContext) {
        self.context = context
    }

    public func generate() throws -> String {
        let namespaces = context.generateNamespaceDefinitions()

        let source = try SourceFileSyntax {
            try ImportDeclSyntax("import ATProtoCore")
            try ImportDeclSyntax("import ATProtoMacro")
            try ImportDeclSyntax("import ATProtoXRPC")
            try ImportDeclSyntax("import Foundation")

            try Generator.namespaces(namespaces)
        }

        let syntax = source.formatted()

        var generated = ""
        syntax.write(to: &generated)

        return generated
    }
}
