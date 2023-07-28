import XCTest

@testable import LexiconGenKit

final class BuilderTests: XCTestCase {
    func testUniqued() throws {
        XCTAssertEqual(
            Builder.uniqued([]),
            []
        )
        XCTAssertEqual(
            Builder.uniqued([
                "Com.Example.Foo.Hoge",
                "Com.Example.Bar.Fuga",
            ]),
            [
                "Hoge",
                "Fuga",
            ]
        )
        XCTAssertEqual(
            Builder.uniqued([
                "Com.Example.Foo.Hoge",
                "Com.Example.Bar.Fuga",
                "Com.Example.Baz.Fuga",
            ]),
            [
                "Hoge",
                "BarFuga",
                "BazFuga",
            ]
        )
    }
}
