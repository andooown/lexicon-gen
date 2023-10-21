import XCTest

@testable import LexiconGenKit

final class StringExtensionsTests: XCTestCase {
    func testHeadUppercased() throws {
        XCTAssertEqual("".headUppercased, "")
        XCTAssertEqual("abc".headUppercased, "Abc")
        XCTAssertEqual("ABC".headUppercased, "ABC")
    }
}
