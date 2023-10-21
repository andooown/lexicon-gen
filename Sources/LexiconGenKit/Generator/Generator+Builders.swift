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

    @CodeBlockItemListBuilder
    static func unknownUnion(from definitions: [SwiftDefinition<LexiconSchema<LexiconAbsoluteReference>>]) throws -> CodeBlockItemListSyntax {
        let records = definitions.filter(\.object.isRecord)

        // public typealias LexiconUnknownUnion = Union2<App.Bsky.Foo.RecordA, App.Bsky.Foo.RecordB>
        try TypeAliasDeclSyntax(
            "public typealias LexiconUnknownUnion = Union\(raw: records.count)<\(raw: records.map(\.fullName).joined(separator: ", "))>"
        )

        // public extension LexiconUnknownUnion {
        //     var asRecordA: App.Bsky.Foo.RecordA? {
        //         asType0
        //     }
        //     var asRecordB: App.Bsky.Foo.RecordB? {
        //         asType1
        //     }
        // }
        try ExtensionDeclSyntax("public extension LexiconUnknownUnion") {
            let uniqued = Builder.uniqued(records.map(\.fullName))
            for (i, (record, unique)) in zip(records, uniqued).enumerated() {
                try VariableDeclSyntax(
                    """
                    var as\(raw: unique): \(raw: record.fullName)? {
                        asType\(raw: i)
                    }
                    """
                )
            }
        }
    }

    @MemberBlockItemListBuilder
    static func definition(_ definition: SwiftDefinition<LexiconSchema<LexiconAbsoluteReference>>) throws -> MemberBlockItemListSyntax {
        switch definition.object {
        case .null:
            Generator.emptySyntax()

        case .boolean:
            try TypeAliasDeclSyntax("typealias \(raw: definition.name) = Bool")

        case .integer:
            try TypeAliasDeclSyntax("typealias \(raw: definition.name) = Int")

        case .string:
            try TypeAliasDeclSyntax("typealias \(raw: definition.name) = String")

        case .bytes:
            Generator.emptySyntax()

        case .cidLink:
            Generator.emptySyntax()

        case .blob:
            Generator.emptySyntax()

        case .array:
            Generator.emptySyntax()

        case .object:
            Generator.emptySyntax()

        case .params:
            Generator.emptySyntax()

        case .token:
            Generator.emptySyntax()

        case .ref:
            Generator.emptySyntax()

        case .union:
            Generator.emptySyntax()

        case .unknown:
            Generator.emptySyntax()

        case .record:
            Generator.emptySyntax()

        case .query:
            Generator.emptySyntax()

        case .procedure:
            Generator.emptySyntax()

        case .subscription:
            Generator.emptySyntax()
        }
    }
}

private extension Generator {
    static func emptySyntax() -> MemberBlockItemListSyntax {
        MemberBlockItemListSyntax(stringLiteral: "")
    }
}
