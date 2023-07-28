import ArgumentParser
import Foundation
import LexiconGenKit
import SwiftFormat
import SwiftSyntax
import SwiftSyntaxBuilder

@main
struct LexiconGen: ParsableCommand {
    @Option
    var sourceDirectory: String
    @Option
    var outputFile: String

    func run() throws {
        print("Source Directory = \(sourceDirectory)")
        print("Output File = \(outputFile)")

        let fileURLs = listJSONFiles(in: URL(filePath: sourceDirectory))

        print("\(fileURLs.count) files found")

        let context = GenerateContext()
        let decoder = JSONDecoder()
        for fileURL in fileURLs {
            let data = try Data(contentsOf: fileURL)
            let lex = try decoder.decode(LexiconDocument<LexiconRelativeReference>.self, from: data)

            context.append(try lex.transformToAbsoluteReferences())
        }

        let namespaces = context.generateNamespaceDefinitions()
        let defs = context.generateDefinitions()
        let records = defs.filter(\.object.isRecord)

        print("\(namespaces.count) namespaces found")
        print("\(defs.count) definitions found")

        let source = SourceFile {
            ImportDecl("import Foundation")
            ImportDecl("import SwiftATProtoXRPC")

            // Namespace enums
            for def in namespaces {
                if def.parent.isEmpty {
                    EnumDecl("public enum \(def.name)") {}
                } else {
                    ExtensionDecl("public extension \(def.parent)") {
                        EnumDecl("enum \(def.name)") {}
                    }
                }
            }

            // Union for unknown schema
            TypealiasDecl(
                "public typealias LexiconUnknownUnion = Union\(raw: records.count)<\(raw: records.map(\.fullName).joined(separator: ", "))>"
            )
            ExtensionDecl("extension LexiconUnknownUnion") {
                let uniqued = Builder.uniqued(records.map(\.fullName))
                for (i, (record, unique)) in zip(records, uniqued).enumerated() {
                    VariableDecl(
                        """
                        public var as\(raw: unique): \(raw: record.fullName)? {
                            asType\(raw: i)
                        }
                        """
                    )
                }
            }

            // Definitions
            for def in defs {
                ExtensionDecl(
                    modifiers: ModifierList([DeclModifierSyntax(name: .public)]),
                    extendedType: Type(stringLiteral: def.parent),
                    membersBuilder: {
                        switch def.object {
                        case .boolean:
                            TypealiasDecl("typealias \(raw: def.name) = Bool")

                        case .integer:
                            TypealiasDecl("typealias \(raw: def.name) = Int")

                        case .string:
                            TypealiasDecl("typealias \(raw: def.name) = String")

                        case .array:
                            if let type = variableType(scheme: def.object) {
                                TypealiasDecl("typealias \(raw: def.name) = \(raw: type)")
                            }

                        case .object(let object):
                            objectDecl(
                                name: def.name,
                                inheritances: ["UnionCodable", "Hashable"],
                                object
                            ) {
                                VariableDecl(
                                    "public static let typeValue = \"\(raw: def.id.valueWithoutMain)\""
                                )
                            }

                        case .union:
                            if let type = variableType(scheme: def.object) {
                                TypealiasDecl("typealias \(raw: def.name) = \(raw: type)")
                            }

                        case .record(let object):
                            objectDecl(
                                name: def.name,
                                inheritances: ["UnionCodable", "Hashable"],
                                object
                            ) {
                                VariableDecl(
                                    "public static let typeValue = \"\(raw: def.id.valueWithoutMain)\""
                                )
                            }

                        case .query(let method), .procedure(let method):
                            StructDecl("struct \(def.name): XRPCRequest") {
                                if let parameters = method.parameters {
                                    objectDecl(
                                        name: "Parameters",
                                        inheritances: ["XRPCRequestParametersConvertible"],
                                        parameters
                                    ) {
                                        let params = parameters.properties
                                            .sorted { $0.key < $1.key }
                                            .compactMap { k, v -> String? in
                                                guard variableType(scheme: v) != nil else {
                                                    return nil
                                                }

                                                return
                                                    "parameters.append(contentsOf: \(k).toQueryItems(name: \"\(k)\"))"
                                            }

                                        VariableDecl(
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

                                switch method.input {
                                case .object(let object):
                                    objectDecl(name: "Input", inheritances: ["Encodable"], object)

                                default:
                                    emptyDecl()
                                }

                                switch method.output {
                                case .object(let object):
                                    objectDecl(
                                        name: "Output",
                                        inheritances: ["Decodable", "Hashable"],
                                        object
                                    )

                                case .ref(let ref):
                                    if let type = variableType(scheme: .ref(ref)) {
                                        TypealiasDecl("public typealias Output = \(raw: type)")
                                    }

                                default:
                                    emptyDecl()
                                }

                                requestInitializerDecl(
                                    parameters: method.parameters,
                                    input: method.input
                                )

                                let requestType = def.object.isQuery ? "query" : "procedure"
                                VariableDecl(
                                    "public let type = XRPCRequestType.\(raw: requestType)"
                                )

                                VariableDecl(
                                    "public let requestIdentifier = \"\(raw: def.id.nsid)\""
                                )

                                if method.parameters != nil {
                                    VariableDecl(
                                        "public let parameters: Parameters"
                                    )
                                }
                                if method.input != nil {
                                    VariableDecl(
                                        "public let input: Input?"
                                    )
                                }
                            }

                        case .subscription:
                            EnumDecl("enum \(def.name)") {}

                        default:
                            emptyDecl()
                        }
                    }
                )
            }
        }
        let syntax = source.formatted()

        var generated = ""
        syntax.write(to: &generated)

        let outputFileURL = URL(filePath: outputFile)
        try generated.write(to: outputFileURL, atomically: true, encoding: .utf8)
    }
}

private extension LexiconGen {
    /// ```swift
    /// public struct Name: Decodable {
    ///     public let requiredVar: T
    ///     public let optionalVar: U?
    /// }
    /// ```
    @MemberDeclListBuilder
    func objectDecl(
        name: String,
        inheritances: [String] = [],
        _ object: LexiconObjectSchema<LexiconAbsoluteReference>,
        @MemberDeclListBuilder additionalBody: () -> MemberDeclList = { MemberDeclList([]) }
    ) -> MemberDeclList {
        let inherit = inheritances.isEmpty ? "" : ": " + inheritances.joined(separator: ", ")
        StructDecl("public struct \(name)\(inherit)") {
            propertiesDecls(object.properties, required: object.required)
            propertiesInitializerDecl(object.properties, required: object.required)

            additionalBody()
        }
    }

    func propertiesDecls(
        _ properties: [String: LexiconSchema<LexiconAbsoluteReference>],
        required: [String]? = nil
    ) -> MemberDeclList {
        propertieDecls(Array(properties), required: required)
    }

    @MemberDeclListBuilder
    func propertieDecls(
        _ properties: [(String, LexiconSchema<LexiconAbsoluteReference>)],
        required: [String]? = nil
    ) -> MemberDeclList {
        let required = required ?? []
        let properties = properties.sorted { $0.0 < $1.0 }

        for (k, v) in properties {
            if let type = variableType(scheme: v) {
                let t = required.contains(k) ? type : "Optional<\(type)>"

                VariableDecl(
                    """
                    @Indirect
                    public var \(raw: k): \(raw: t)
                    """
                )
            }
        }
    }

    func propertiesInitializerDecl(
        _ properties: [String: LexiconSchema<LexiconAbsoluteReference>],
        required: [String]? = nil
    ) -> InitializerDecl {
        propertiesInitializerDecl(Array(properties), required: required)
    }

    func propertiesInitializerDecl(
        _ properties: [(String, LexiconSchema<LexiconAbsoluteReference>)],
        required: [String]? = nil
    ) -> InitializerDecl {
        var signatures = [String]()
        var assignments = [String]()

        let required = required ?? []
        for (k, v) in properties.sorted(by: { $0.0 < $1.0 }) {
            if let type = variableType(scheme: v) {
                let isRequired = required.contains(k)
                let t = isRequired ? type : "Optional<\(type)>"

                signatures.append("\(k): \(t)\(isRequired ? "" : " = nil")")
                assignments.append("self._\(k) = .wrapped(\(k))")
            }
        }

        return InitializerDecl(
            """
            public init(
                \(raw: signatures.joined(separator: ",\n"))
            ) {
                \(raw: assignments.joined(separator: "\n"))
            }
            """
        )
    }

    func requestInitializerDecl(
        parameters: LexiconObjectSchema<LexiconAbsoluteReference>?,
        input: LexiconSchema<LexiconAbsoluteReference>?
    ) -> InitializerDecl {
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

        return InitializerDecl(
            """
            public init(
                \(raw: signatures.joined(separator: ",\n"))
            ) {
                \(raw: assignments.joined(separator: "\n"))
            }
            """
        )
    }

    func emptyDecl() -> MemberDeclList {
        MemberDeclList([])
    }

    func listJSONFiles(in baseDirectory: URL) -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: baseDirectory,
                includingPropertiesForKeys: nil
            )
        else {
            return []
        }

        return enumerator.compactMap { $0 as? URL }.filter {
            $0.pathExtension.lowercased() == "json"
        }
    }

    func variableType(scheme: LexiconSchema<LexiconAbsoluteReference>) -> String? {
        switch scheme {
        case .null:
            return nil

        case .boolean:
            return "Bool"

        case .integer:
            return "Int"

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
            return variableType(scheme: element).map { "[" + $0 + "]" }

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
            let types = refs.compactMap { variableType(scheme: .ref($0)) }
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
}

private extension String {
    var headUppercased: String {
        prefix(1).uppercased() + dropFirst()
    }
}
