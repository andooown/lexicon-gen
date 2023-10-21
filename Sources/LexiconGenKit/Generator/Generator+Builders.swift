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
            .string,
            .array,
            .union:
            if let typeName = Generator.swiftTypeName(for: definition.object) {
                try TypeAliasDeclSyntax("typealias \(raw: definition.name) = \(raw: typeName)")
            }

        case .object(let object),
            .record(let object):
            try Generator.objectSyntax(
                name: definition.name,
                inheritances: ["UnionCodable", "Hashable"],
                object: object
            ) {
                try VariableDeclSyntax(
                    "public static let typeValue = #LexiconDefID(\"\(raw: definition.id.valueWithoutMain)\")"
                )
            }

        case .query(let method),
            .procedure(let method):
            try StructDeclSyntax("struct \(raw: definition.name): XRPCRequest") {
                // Parameters
                if let parameters = method.parameters {
                    try objectSyntax(
                        name: "Parameters",
                        modifiers: ["public"],
                        inheritances: ["XRPCRequestParametersConvertible"],
                        object: parameters
                    ) {
                        let params = parameters.properties
                            .sorted { $0.key < $1.key }
                            .compactMap { k, v -> String? in
                                guard Generator.swiftTypeName(for: v) != nil else {
                                    return nil
                                }

                                return "parameters.append(contentsOf: \(k).toQueryItems(name: \"\(k)\"))"
                            }

                        try VariableDeclSyntax(
                            """
                            public var queryItems: [URLQueryItem] {
                                var parameters = [URLQueryItem]()
                                \(raw: params.joined(separator: "\n"))

                                return parameters
                            }
                            """
                        )
                    }
                }

                // Input
                switch method.input {
                case .object(let object):
                    try objectSyntax(
                        name: "Input",
                        modifiers: ["public"],
                        inheritances: ["Encodable"],
                        object: object
                    )

                default:
                    Generator.emptySyntax()
                }

                // Output
                switch method.output {
                case .object(let object):
                    try objectSyntax(
                        name: "Output",
                        modifiers: ["public"],
                        inheritances: ["Decodable", "Hashable"],
                        object: object
                    )

                case .ref(let ref):
                    if let type = Generator.swiftTypeName(for: .ref(ref)) {
                        try TypeAliasDeclSyntax("public typealias Output = \(raw: type)")
                    }

                default:
                    Generator.emptySyntax()
                }

                // Initializer
                Generator.requestInitializerSyntax(
                    parameters: method.parameters,
                    input: method.input
                )

                let requestType = definition.object.isQuery ? "query" : "procedure"
                try VariableDeclSyntax(
                    "public let type = XRPCRequestType.\(raw: requestType)"
                )

                try VariableDeclSyntax(
                    "public let requestIdentifier = \"\(raw: definition.id.nsid)\""
                )

                if method.parameters != nil {
                    try VariableDeclSyntax(
                        "public let parameters: Parameters"
                    )
                }
                if method.input != nil {
                    try VariableDeclSyntax(
                        "public let input: Input?"
                    )
                }
            }

        case .subscription:
            try EnumDeclSyntax("enum \(raw: definition.name)") {}

        default:
            Generator.emptySyntax()
        }
    }

    @MemberBlockItemListBuilder
    static func objectSyntax(
        name: String,
        modifiers: [String] = [],
        inheritances: [String] = [],
        object: LexiconObjectSchema<LexiconAbsoluteReference>,
        @MemberBlockItemListBuilder additionalBody: () throws -> MemberBlockItemListSyntax = { MemberBlockItemListSyntax([]) }
    ) throws -> MemberBlockItemListSyntax {
        let modifier = modifiers.isEmpty ? "" : modifiers.joined(separator: " ") + " "
        let inherit = inheritances.isEmpty ? "" : ": " + inheritances.joined(separator: ", ")

        try StructDeclSyntax("\(raw: modifier)struct \(raw: name)\(raw: inherit)") {
            try Generator.objectPropertiesSyntax(object.properties, required: object.required)
            Generator.objectInitializerSyntax(object.properties, required: object.required)

            try additionalBody()
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

    @MemberBlockItemListBuilder
    static func objectPropertiesSyntax(
        _ properties: [String: LexiconSchema<LexiconAbsoluteReference>],
        required: [String]? = nil
    ) throws -> MemberBlockItemListSyntax {
        let required = required ?? []
        let properties = properties.sorted { $0.0 < $1.0 }

        for (k, v) in properties {
            if let type = swiftTypeName(for: v) {
                let t = required.contains(k) ? type : "\(type)?"

                try VariableDeclSyntax(
                    """
                    @Indirect
                    public var \(raw: k): \(raw: t)
                    """
                )
            }
        }
    }

    static func objectInitializerSyntax(
        _ properties: [String: LexiconSchema<LexiconAbsoluteReference>],
        required: [String]? = nil
    ) -> DeclSyntax {
        var signatures = [String]()
        var assignments = [String]()

        let required = required ?? []
        for (k, v) in properties.sorted(by: { $0.0 < $1.0 }) {
            if let type = swiftTypeName(for: v) {
                let isRequired = required.contains(k)
                let t = isRequired ? type : "\(type)?"

                signatures.append("\(k): \(t)\(isRequired ? "" : " = nil")")
                assignments.append("self._\(k) = .wrapped(\(k))")
            }
        }

        return DeclSyntax(
            """
            public init(
                \(raw: signatures.joined(separator: ",\n"))
            ) {
                \(raw: assignments.joined(separator: "\n"))
            }
            """
        )
    }

    static func requestInitializerSyntax(
        parameters: LexiconObjectSchema<LexiconAbsoluteReference>?,
        input: LexiconSchema<LexiconAbsoluteReference>?
    ) -> DeclSyntax {
        var signatures = [String]()
        var assignments = [String]()

        if parameters != nil {
            signatures.append("parameters: Parameters")
            assignments.append("self.parameters = parameters")
        }

        if input != nil {
            signatures.append("input: Input")
            assignments.append("self.input = input")
        }

        return DeclSyntax(
            """
            public init(
                \(raw: signatures.joined(separator: ",\n"))
            ) {
                \(raw: assignments.joined(separator: "\n"))
            }
            """
        )
    }

    static func emptySyntax() -> MemberBlockItemListSyntax {
        MemberBlockItemListSyntax(stringLiteral: "")
    }
}
