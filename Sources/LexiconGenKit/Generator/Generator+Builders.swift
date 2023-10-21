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

        case .boolean,
            .integer,
            .string:
            if let typeName = Generator.swiftTypeName(for: definition.object) {
                try TypeAliasDeclSyntax("typealias \(raw: definition.name) = \(raw: typeName)")
            }

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
    static func swiftTypeName(for scheme: LexiconSchema<LexiconAbsoluteReference>) -> String? {
        switch scheme {
        case .null:
            return nil

        case .boolean:
            return "Bool"

        case .integer:
            return "Int"

        case .string(format: "at-uri"):
            return "ATURI"

        case .string(format: "datetime"):
            return "Date"

        case .string(format: "uri"):
            return "SafeURL"

        case .string:
            return "String"

        case .bytes:
            return nil

        case .cidLink:
            return nil

        case .blob:
            return nil

        case .array(let element):
            return swiftTypeName(for: element).map { "[" + $0 + "]" }

        case .object:
            return nil

        case .params:
            return nil

        case .token:
            return nil

        case .ref(let ref):
            if ref.rawValue.contains("#") {
                let (parent, name) = ref.definitionID.swiftDefinitionNames
                return parent + "." + name
            } else {
                return ref.rawValue.split(separator: ".").map(String.init).map(\.headUppercased)
                    .joined(
                        separator: "."
                    )
            }

        case .union(let refs):
            let types = refs.compactMap { swiftTypeName(for: .ref($0)) }
            guard !types.isEmpty else {
                return nil
            }
            return "Union\(types.count)<\(types.joined(separator: ", "))>"

        case .unknown:
            return "LexiconUnknownUnion"

        case .record:
            return nil

        case .query:
            return nil

        case .procedure:
            return nil

        case .subscription:
            return nil
        }
    }

    static func emptySyntax() -> MemberBlockItemListSyntax {
        MemberBlockItemListSyntax(stringLiteral: "")
    }
}
