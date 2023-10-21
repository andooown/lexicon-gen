import CustomDump
import XCTest

@testable import LexiconGenKit

final class GeneratorBuildersTests: XCTestCase {
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
                SwiftDefinition(id: LexiconDefinitionID("com.example.foo#a"), parent: "Com.Example.Foo", name: "A", object: .record(object)),
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
                SwiftDefinition(id: LexiconDefinitionID("com.example.foo#a"), parent: "Com.Example.Foo", name: "A", object: .record(object)),
                SwiftDefinition(id: LexiconDefinitionID("com.example.foo#b"), parent: "Com.Example.Foo", name: "B", object: .record(object)),
                SwiftDefinition(id: LexiconDefinitionID("com.example.Bar#b"), parent: "Com.Example.Bar", name: "B", object: .record(object)),
                SwiftDefinition(id: LexiconDefinitionID("com.example.Baz#c"), parent: "Com.Example.Baz", name: "C", object: .boolean),
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
}
