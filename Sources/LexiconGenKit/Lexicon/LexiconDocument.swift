import Foundation

public struct LexiconDocument<Reference>: Decodable where Reference: LexiconReference {
    public var lexicon: Int
    public var id: NSID
    public var revision: Int?
    public var description: String?
    public var defs: [String: LexiconSchema<Reference>]

    public func transformToAbsoluteReferences() throws -> LexiconDocument<LexiconAbsoluteReference>
    {
        try LexiconDocument<LexiconAbsoluteReference>(
            lexicon: lexicon,
            id: id,
            revision: revision,
            description: description,
            defs: defs.mapValues { try $0.transformToAbsoluteReference(nsid: id) }
        )
    }
}
