import XCTest

@testable import LexiconGenKit

final class LexiconReferenceTests: XCTestCase {
    func testAbsoluteReference() throws {
        let inputs: [LexiconRelativeReference] = [
            .init(rawValue: "object"),
            .init(rawValue: "#object"),
            .init(rawValue: "com.example.foo#object"),
            .init(rawValue: "com.example.foo"),
        ]

        let outputs: [LexiconAbsoluteReference] = try [
            .init(rawValue: "com.example.root#object"),
            .init(rawValue: "com.example.root#object"),
            .init(rawValue: "com.example.foo#object"),
            .init(rawValue: "com.example.foo#main"),
        ]

        XCTAssertEqual(inputs.count, outputs.count)

        let nsid = try NSID("com.example.root")
        for (input, output) in zip(inputs, outputs) {
            XCTAssertEqual(try input.absoluteReference(nsid: nsid), output)
        }
    }
}
