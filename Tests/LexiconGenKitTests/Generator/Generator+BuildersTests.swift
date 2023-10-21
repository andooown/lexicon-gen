import CustomDump
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

@testable import LexiconGenKit

final class GeneratorBuildersTests: XCTestCase {
    private typealias AbsoluteSwiftDefinition = SwiftDefinition<LexiconSchema<LexiconAbsoluteReference>>

    func testNamespaces() throws {
        XCTAssertNoDifference(
            try Generator.namespaces([
                SwiftNamespaceDefinition(parent: "", name: "Foo"),
            ]).formatted().description,
            """
            public enum Foo {
            }
            """
        )
        XCTAssertNoDifference(
            try Generator.namespaces([
                SwiftNamespaceDefinition(parent: "", name: "Foo"),
                SwiftNamespaceDefinition(parent: "Foo", name: "Bar"),
                SwiftNamespaceDefinition(parent: "Foo.Bar", name: "Baz"),
                SwiftNamespaceDefinition(parent: "Foo.Bar", name: "Qux"),
            ]).formatted().description,
            """
            public enum Foo {
            }
            public extension Foo {
                enum Bar {
                }
            }
            public extension Foo.Bar {
                enum Baz {
                }
            }
            public extension Foo.Bar {
                enum Qux {
                }
            }
            """
        )
    }

    func testUnknownUnion() throws {
        let object = LexiconObjectSchema<LexiconAbsoluteReference>(properties: [:], required: nil)

        XCTAssertNoDifference(
            try Generator.unknownUnion(from: [
                AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.foo#a"), parent: "Com.Example.Foo", name: "A", object: .record(object)),
            ]).formatted().description,
            """
            public typealias LexiconUnknownUnion = Union1<Com.Example.Foo.A>
            public extension LexiconUnknownUnion {
                var asA: Com.Example.Foo.A? {
                    asType0
                }
            }
            """
        )
        XCTAssertNoDifference(
            try Generator.unknownUnion(from: [
                AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.foo#a"), parent: "Com.Example.Foo", name: "A", object: .record(object)),
                AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.foo#b"), parent: "Com.Example.Foo", name: "B", object: .record(object)),
                AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.Bar#b"), parent: "Com.Example.Bar", name: "B", object: .record(object)),
                AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.Baz#c"), parent: "Com.Example.Baz", name: "C", object: .boolean),
            ]).formatted().description,
            """
            public typealias LexiconUnknownUnion = Union3<Com.Example.Foo.A, Com.Example.Foo.B, Com.Example.Bar.B>
            public extension LexiconUnknownUnion {
                var asA: Com.Example.Foo.A? {
                    asType0
                }
                var asFooB: Com.Example.Foo.B? {
                    asType1
                }
                var asBarB: Com.Example.Bar.B? {
                    asType2
                }
            }
            """
        )
    }

    func testDefinition() throws {
        func makeDefinition(_ object: LexiconSchema<LexiconAbsoluteReference>) throws -> AbsoluteSwiftDefinition {
            try AbsoluteSwiftDefinition(
                id: LexiconDefinitionID("com.example.foo#main"),
                parent: "Com.Example",
                name: "Foo",
                object: object
            )
        }

        // boolean
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.boolean)).formatted().description,
            """
            typealias Foo = Bool
            """
        )

        // integer
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.integer)).formatted().description,
            """
            typealias Foo = Int
            """
        )

        // string
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.string(format: nil))).formatted().description,
            """
            typealias Foo = String
            """
        )
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.string(format: "at-uri"))).formatted().description,
            """
            typealias Foo = ATURI
            """
        )
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.string(format: "datetime"))).formatted().description,
            """
            typealias Foo = Date
            """
        )
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.string(format: "uri"))).formatted().description,
            """
            typealias Foo = SafeURL
            """
        )

        // array
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.array(.boolean))).formatted().description,
            """
            typealias Foo = [Bool]
            """
        )
        XCTAssertNoDifference(
            try Generator.definition(makeDefinition(.array(.integer))).formatted().description,
            """
            typealias Foo = [Int]
            """
        )

        // union
        XCTAssertNoDifference(
            try Generator.definition(
                makeDefinition(
                    .union(
                        [
                            LexiconAbsoluteReference(LexiconDefinitionID("com.example.foo#main")),
                            LexiconAbsoluteReference(LexiconDefinitionID("com.example.foo#record")),
                        ]
                    )
                )
            ).formatted().description,
            """
            typealias Foo = Union2<Com.Example.Foo, Com.Example.Foo.Record>
            """
        )

        // object
        XCTAssertNoDifference(
            try Generator.definition(
                makeDefinition(
                    .object(
                        LexiconObjectSchema(
                            properties: [
                                "requiredValue": .integer,
                                "optionalValue": .string(format: nil)
                            ],
                            required: ["requiredValue"]
                        )
                    )
                )
            ).formatted().description,
            """
            public struct Foo: UnionCodable, Hashable {
                @Indirect
                public var optionalValue: String?
                @Indirect
                public var requiredValue: Int
                public init(
                    optionalValue: String? = nil,
                    requiredValue: Int
                ) {
                    self._optionalValue = .wrapped(optionalValue)
                    self._requiredValue = .wrapped(requiredValue)
                }
                public static let typeValue = #LexiconDefID("com.example.foo")
            }
            """
        )

        // record
        XCTAssertNoDifference(
            try Generator.definition(
                makeDefinition(
                    .record(
                        LexiconObjectSchema(
                            properties: [
                                "requiredValue": .integer,
                                "optionalValue": .string(format: nil)
                            ],
                            required: ["requiredValue"]
                        )
                    )
                )
            ).formatted().description,
            """
            public struct Foo: UnionCodable, Hashable {
                @Indirect
                public var optionalValue: String?
                @Indirect
                public var requiredValue: Int
                public init(
                    optionalValue: String? = nil,
                    requiredValue: Int
                ) {
                    self._optionalValue = .wrapped(optionalValue)
                    self._requiredValue = .wrapped(requiredValue)
                }
                public static let typeValue = #LexiconDefID("com.example.foo")
            }
            """
        )
    }

    func testObjectSyntax() throws {
        XCTAssertNoDifference(
            try Generator.objectSyntax(
                name: "Object",
                inheritances: [
                    "Protocol1",
                    "Protocol2"
                ],
                object: LexiconObjectSchema(
                    properties: [
                        "foo": .boolean,
                        "bar": .integer,
                    ],
                    required: [
                        "foo"
                    ]
                ),
                additionalBody: {
                    try VariableDeclSyntax("public let baz = 123")
                }
            ).formatted().description,
            """
            public struct Object: Protocol1, Protocol2 {
                @Indirect
                public var bar: Int?
                @Indirect
                public var foo: Bool
                public init(
                    bar: Int? = nil,
                    foo: Bool
                ) {
                    self._bar = .wrapped(bar)
                    self._foo = .wrapped(foo)
                }
                public let baz = 123
            }
            """
        )
    }
}
