public protocol LexiconReference: Decodable, Equatable {
    init(rawValue: String) throws

    var rawValue: String { get }

    func absoluteReference(nsid: NSID) throws -> LexiconAbsoluteReference
}

public struct LexiconRelativeReference: LexiconReference {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public func absoluteReference(nsid: NSID) throws -> LexiconAbsoluteReference {
        if rawValue.hasPrefix("#") {
            return LexiconAbsoluteReference(
                LexiconDefinitionID(nsid: nsid, name: String(rawValue.dropFirst()))
            )
        } else if rawValue.contains("#") {
            return LexiconAbsoluteReference(try LexiconDefinitionID(rawValue))
        } else if rawValue.contains(".") {
            return LexiconAbsoluteReference(
                LexiconDefinitionID(nsid: try NSID(rawValue), name: "main")
            )
        } else {
            return LexiconAbsoluteReference(LexiconDefinitionID(nsid: nsid, name: rawValue))
        }
    }
}

public struct LexiconAbsoluteReference: LexiconReference {
    public let definitionID: LexiconDefinitionID

    public init(_ definitionID: LexiconDefinitionID) {
        self.definitionID = definitionID
    }

    public init(rawValue: String) throws {
        self.definitionID = try LexiconDefinitionID(rawValue)
    }

    public var rawValue: String {
        definitionID.value
    }

    public func absoluteReference(nsid: NSID) throws -> LexiconAbsoluteReference {
        self
    }
}
