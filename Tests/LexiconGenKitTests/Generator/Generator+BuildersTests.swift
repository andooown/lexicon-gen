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
}
