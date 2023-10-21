import SwiftSyntax
import SwiftSyntaxBuilder

public struct Generator {
    private let context: GeneratorContext

    public init(context: GeneratorContext) {
        self.context = context
    }

    public func generate() throws -> String {
        let namespaces = context.generateNamespaceDefinitions()
        let definitions = context.generateDefinitions()

        let source = try SourceFileSyntax {
            try ImportDeclSyntax("import ATProtoCore")
            try ImportDeclSyntax("import ATProtoMacro")
            try ImportDeclSyntax("import ATProtoXRPC")
            try ImportDeclSyntax("import Foundation")

            try Generator.namespaces(namespaces)

            try Generator.unknownUnion(from: definitions)

            for definition in definitions {
                try ExtensionDeclSyntax(
                    modifiers: [DeclModifierSyntax(name: .keyword(.public))],
                    extendedType: TypeSyntax(stringLiteral: definition.parent)
                ) {
                    try Generator.definition(definition)
                }
            }
        }

        let syntax = source.formatted()

        var generated = ""
        syntax.write(to: &generated)

        return generated
    }
}
