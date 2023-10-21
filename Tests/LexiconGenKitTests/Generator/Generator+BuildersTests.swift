import CustomDump
import XCTest

@testable import LexiconGenKit

final class GeneratorBuildersTests: XCTestCase {
    func testNamespaces() throws {
        XCTAssertNoDifference(
            try Generator.namespaces([
            ]).description,
            """
            """
        )
    }
}
