import Foundation

public struct NSID: Hashable, Decodable, CustomStringConvertible {
    public enum Error: Swift.Error {
        case lackOfParts
    }

    /// `com.example.foo` -> `["com", "example", "foo"]`
    public let segments: [String]

    public init(segments: [String]) {
        self.segments = segments
    }

    public init(_ rawValue: String) throws {
        let labels = rawValue.split(separator: ".").map(String.init)
        guard labels.count >= 3 else {
            throw Error.lackOfParts
        }

        self.segments = labels
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        do {
            try self.init(rawValue)
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "error occurs during initializing from raw string"
                )
            )
        }
    }

    public var value: String {
        segments.joined(separator: ".")
    }

    public var description: String {
        value
    }
}

public struct LexiconDefinitionID: Hashable, Decodable, CustomStringConvertible {
    public enum Error: Swift.Error {
        case malformed
    }

    public let nsid: NSID
    public let name: String

    public init(nsid: NSID, name: String) {
        self.nsid = nsid
        self.name = name
    }

    public init(_ rawValue: String) throws {
        let components = rawValue.split(separator: "#").map(String.init)
        guard components.count == 2 else {
            throw Error.malformed
        }

        self.nsid = try NSID(components[0])
        self.name = components[1]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        do {
            try self.init(rawValue)
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "error occurs during initializing from raw string"
                )
            )
        }
    }

    public var isMain: Bool {
        name == "main"
    }

    public var value: String {
        nsid.value + "#" + name
    }

    public var valueWithoutMain: String {
        nsid.value + (name == "main" ? "" : "#" + name)
    }

    public var description: String {
        value
    }
}
