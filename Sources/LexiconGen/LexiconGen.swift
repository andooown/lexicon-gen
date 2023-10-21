import ArgumentParser
import Foundation
import LexiconGenKit
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

        let fileURLs = listJSONFiles(in: URL(fileURLWithPath: sourceDirectory, isDirectory: true))

        print("\(fileURLs.count) files found")

        let context = GeneratorContext()
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

        print("Generating...")
        let start = Date()
        let generated = try Generator(context: context).generate()
        print("Completed in \(String(format: "%.3f", Date().timeIntervalSince(start))) s")

        let outputFileURL = URL(fileURLWithPath: outputFile)
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
    @MemberBlockItemListBuilder
    func objectDecl(
        name: String,
        inheritances: [String] = [],
        _ object: LexiconObjectSchema<LexiconAbsoluteReference>,
        @MemberBlockItemListBuilder additionalBody: () throws -> MemberBlockItemListSyntax = { MemberBlockItemListSyntax([]) }
    ) throws -> MemberBlockItemListSyntax {
        let inherit = inheritances.isEmpty ? "" : ": " + inheritances.joined(separator: ", ")
        try StructDeclSyntax("public struct \(raw: name)\(raw: inherit)") {
            try propertiesDecls(object.properties, required: object.required)
            propertiesInitializerDecl(object.properties, required: object.required)

            try additionalBody()
        }
    }

    func propertiesDecls(
        _ properties: [String: LexiconSchema<LexiconAbsoluteReference>],
        required: [String]? = nil
    ) throws -> MemberBlockItemListSyntax {
        try propertieDecls(Array(properties), required: required)
    }

    @MemberBlockItemListBuilder
    func propertieDecls(
        _ properties: [(String, LexiconSchema<LexiconAbsoluteReference>)],
        required: [String]? = nil
    ) throws -> MemberBlockItemListSyntax {
        let required = required ?? []
        let properties = properties.sorted { $0.0 < $1.0 }

        for (k, v) in properties {
            if let type = variableType(scheme: v) {
                let t = required.contains(k) ? type : "Optional<\(type)>"

                try VariableDeclSyntax(
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
    ) -> DeclSyntax {
        propertiesInitializerDecl(Array(properties), required: required)
    }

    func propertiesInitializerDecl(
        _ properties: [(String, LexiconSchema<LexiconAbsoluteReference>)],
        required: [String]? = nil
    ) -> DeclSyntax {
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

    func requestInitializerDecl(
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

    func emptyDecl() -> MemberBlockItemListSyntax {
        MemberBlockItemListSyntax(stringLiteral: "")
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
