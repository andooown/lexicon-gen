import XCTest

@testable import LexiconGenKit

final class LexiconSchemeTests: XCTestCase {
    func testTransformToAbsoluteReference() throws {
        let inputs: [LexiconSchema<LexiconRelativeReference>] = [
            .null,
            .boolean,
            .integer,
            .string(format: "FORMAT"),
            .bytes,
            .cidLink,
            .blob,
            .array(.ref(.init(rawValue: "#type"))),
            .object(
                LexiconObjectSchema(
                    properties: [
                        "a": .ref(.init(rawValue: "#typeA")), "b": .ref(.init(rawValue: "#typeB")),
                    ],
                    required: ["a"]
                )
            ),
            .params,
            .token,
            .ref(.init(rawValue: "#ref")),
            .union([.init(rawValue: "#ref"), .init(rawValue: "com.namespace.absolute#ref")]),
            .unknown,
            .record(
                LexiconObjectSchema(
                    properties: [
                        "a": .ref(.init(rawValue: "#typeA")), "b": .ref(.init(rawValue: "#typeB")),
                    ],
                    required: ["a"]
                )
            ),
            .query(
                LexiconMethodSchema(
                    parameters: LexiconObjectSchema(
                        properties: [
                            "paramA": .ref(.init(rawValue: "#typeA")),
                            "paramB": .ref(.init(rawValue: "#typeB")),
                        ],
                        required: ["paramA"]
                    ),
                    input: .object(
                        LexiconObjectSchema(
                            properties: [
                                "inputA": .ref(.init(rawValue: "#typeA")),
                                "inputB": .ref(.init(rawValue: "#typeB")),
                            ],
                            required: ["inputA"]
                        )
                    ),
                    output: .object(
                        LexiconObjectSchema(
                            properties: [
                                "outputA": .ref(.init(rawValue: "#typeA")),
                                "outputB": .ref(.init(rawValue: "#typeB")),
                            ],
                            required: ["outputA"]
                        )
                    )
                )
            ),
            .procedure(
                LexiconMethodSchema(
                    parameters: LexiconObjectSchema(
                        properties: [
                            "paramA": .ref(.init(rawValue: "#typeA")),
                            "paramB": .ref(.init(rawValue: "#typeB")),
                        ],
                        required: ["paramA"]
                    ),
                    input: .object(
                        LexiconObjectSchema(
                            properties: [
                                "inputA": .ref(.init(rawValue: "#typeA")),
                                "inputB": .ref(.init(rawValue: "#typeB")),
                            ],
                            required: ["inputA"]
                        )
                    ),
                    output: .object(
                        LexiconObjectSchema(
                            properties: [
                                "outputA": .ref(.init(rawValue: "#typeA")),
                                "outputB": .ref(.init(rawValue: "#typeB")),
                            ],
                            required: ["outputA"]
                        )
                    )
                )
            ),
            .subscription,
        ]

        let outputs: [LexiconSchema<LexiconAbsoluteReference>] = try [
            .null,
            .boolean,
            .integer,
            .string(format: "FORMAT"),
            .bytes,
            .cidLink,
            .blob,
            .array(.ref(.init(rawValue: "com.example.root#type"))),
            .object(
                LexiconObjectSchema(
                    properties: [
                        "a": .ref(.init(rawValue: "com.example.root#typeA")),
                        "b": .ref(.init(rawValue: "com.example.root#typeB")),
                    ],
                    required: ["a"]
                )
            ),
            .params,
            .token,
            .ref(.init(rawValue: "com.example.root#ref")),
            .union([
                .init(rawValue: "com.example.root#ref"),
                .init(rawValue: "com.namespace.absolute#ref"),
            ]),
            .unknown,
            .record(
                LexiconObjectSchema(
                    properties: [
                        "a": .ref(.init(rawValue: "com.example.root#typeA")),
                        "b": .ref(.init(rawValue: "com.example.root#typeB")),
                    ],
                    required: ["a"]
                )
            ),
            .query(
                LexiconMethodSchema(
                    parameters: LexiconObjectSchema(
                        properties: [
                            "paramA": .ref(.init(rawValue: "com.example.root#typeA")),
                            "paramB": .ref(.init(rawValue: "com.example.root#typeB")),
                        ],
                        required: ["paramA"]
                    ),
                    input: .object(
                        LexiconObjectSchema(
                            properties: [
                                "inputA": .ref(.init(rawValue: "com.example.root#typeA")),
                                "inputB": .ref(.init(rawValue: "com.example.root#typeB")),
                            ],
                            required: ["inputA"]
                        )
                    ),
                    output: .object(
                        LexiconObjectSchema(
                            properties: [
                                "outputA": .ref(.init(rawValue: "com.example.root#typeA")),
                                "outputB": .ref(.init(rawValue: "com.example.root#typeB")),
                            ],
                            required: ["outputA"]
                        )
                    )
                )
            ),
            .procedure(
                LexiconMethodSchema(
                    parameters: LexiconObjectSchema(
                        properties: [
                            "paramA": .ref(.init(rawValue: "com.example.root#typeA")),
                            "paramB": .ref(.init(rawValue: "com.example.root#typeB")),
                        ],
                        required: ["paramA"]
                    ),
                    input: .object(
                        LexiconObjectSchema(
                            properties: [
                                "inputA": .ref(.init(rawValue: "com.example.root#typeA")),
                                "inputB": .ref(.init(rawValue: "com.example.root#typeB")),
                            ],
                            required: ["inputA"]
                        )
                    ),
                    output: .object(
                        LexiconObjectSchema(
                            properties: [
                                "outputA": .ref(.init(rawValue: "com.example.root#typeA")),
                                "outputB": .ref(.init(rawValue: "com.example.root#typeB")),
                            ],
                            required: ["outputA"]
                        )
                    )
                )
            ),
            .subscription,
        ]

        XCTAssertEqual(inputs.count, outputs.count)

        let nsid = try NSID("com.example.root")
        for (input, output) in zip(inputs, outputs) {
            XCTAssertEqual(try input.transformToAbsoluteReference(nsid: nsid), output)
        }
    }
}
