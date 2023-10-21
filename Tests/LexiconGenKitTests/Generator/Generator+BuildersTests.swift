import CustomDump
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
        // boolean
        let boolean = try AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.foo#main"), parent: "Com.Example", name: "Foo", object: .boolean)
        XCTAssertNoDifference(
            try Generator.definition(boolean).formatted().description,
            """
            typealias Foo = Bool
            """
        )

        // integer
        let integer = try AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.foo#main"), parent: "Com.Example", name: "Foo", object: .integer)
        XCTAssertNoDifference(
            try Generator.definition(integer).formatted().description,
            """
            typealias Foo = Int
            """
        )

        // string
        let string = try AbsoluteSwiftDefinition(id: LexiconDefinitionID("com.example.foo#main"), parent: "Com.Example", name: "Foo", object: .string(format: nil))
        XCTAssertNoDifference(
            try Generator.definition(string).formatted().description,
            """
            typealias Foo = String
            """
        )
    }
}
