public class LexiconDocumentCollection<Reference> where Reference: LexiconReference {
    public typealias Document = LexiconDocument<Reference>

    public private(set) var docs = [Document]()

    public init() {
    }
}

public extension LexiconDocumentCollection {
    func add(_ doc: Document) {
        docs.append(doc)
    }

    func generateDefinitions() -> [LexiconDefinitionID: LexiconSchema<Reference>] {
        var defs = [LexiconDefinitionID: LexiconSchema<Reference>]()
        for doc in docs {
            defs.merge(
                doc.defs.map { (LexiconDefinitionID(nsid: doc.id, name: $0.key), $0.value) },
                uniquingKeysWith: { $1 }
            )
        }

        return defs
    }
}
