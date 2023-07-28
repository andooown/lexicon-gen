public struct LexiconObjectSchema<Reference>: Decodable, Equatable
where Reference: LexiconReference {
    public let properties: [String: LexiconSchema<Reference>]
    public let required: [String]?

    public init(properties: [String: LexiconSchema<Reference>], required: [String]?) {
        self.properties = properties
        self.required = required
    }

    public func transformToAbsoluteReference(nsid: NSID) throws -> LexiconObjectSchema<
        LexiconAbsoluteReference
    > {
        try LexiconObjectSchema<LexiconAbsoluteReference>(
            properties: properties.mapValues {
                try $0.transformToAbsoluteReference(nsid: nsid)
            },
            required: required
        )
    }
}

public struct LexiconMethodSchema<Reference>: Decodable, Equatable
where Reference: LexiconReference {
    private enum CodingKeys: String, CodingKey {
        case parameters
        case input
        case output
    }

    private enum ObjectCodingKeys: String, CodingKey {
        case schema
    }

    public let parameters: LexiconObjectSchema<Reference>?
    public let input: LexiconSchema<Reference>?
    public let output: LexiconSchema<Reference>?

    public init(
        parameters: LexiconObjectSchema<Reference>?,
        input: LexiconSchema<Reference>?,
        output: LexiconSchema<Reference>?
    ) {
        self.parameters = parameters
        self.input = input
        self.output = output
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        parameters = try container.decodeIfPresent(
            LexiconObjectSchema<Reference>.self,
            forKey: .parameters
        )

        if container.contains(.input) {
            let inputContainer = try container.nestedContainer(
                keyedBy: ObjectCodingKeys.self,
                forKey: .input
            )
            input = try inputContainer.decodeIfPresent(
                LexiconSchema<Reference>.self,
                forKey: .schema
            )
        } else {
            input = nil
        }

        if container.contains(.output) {
            let outputContainer = try container.nestedContainer(
                keyedBy: ObjectCodingKeys.self,
                forKey: .output
            )
            // NOTE: `schema` is marked as required but `com.atproto.sync.getBlob` is not compliant it.
            output = try outputContainer.decodeIfPresent(
                LexiconSchema<Reference>.self,
                forKey: .schema
            )
        } else {
            output = nil
        }

    }

    public func transformToAbsoluteReference(nsid: NSID) throws -> LexiconMethodSchema<
        LexiconAbsoluteReference
    > {
        try LexiconMethodSchema<LexiconAbsoluteReference>(
            parameters: parameters?.transformToAbsoluteReference(nsid: nsid),
            input: input?.transformToAbsoluteReference(nsid: nsid),
            output: output?.transformToAbsoluteReference(nsid: nsid)
        )
    }
}

public enum LexiconSchema<Reference>: Decodable, Equatable where Reference: LexiconReference {
    case null
    case boolean
    case integer
    case string(format: String?)
    case bytes
    case cidLink
    case blob
    indirect case array(LexiconSchema)
    case object(LexiconObjectSchema<Reference>)
    case params  // TODO
    case token  // TODO
    case ref(Reference)  // TODO
    case union([Reference])  // TODO
    case unknown
    case record(LexiconObjectSchema<Reference>)
    indirect case query(LexiconMethodSchema<Reference>)
    indirect case procedure(LexiconMethodSchema<Reference>)
    case subscription  //TODO

    private enum TypeCodingKeys: String, CodingKey {
        case type
    }

    private enum LexiconType: String, Decodable {
        case null
        case boolean
        case integer
        case string
        case bytes
        case cidLink = "cid-link"
        case blob
        case array
        case object
        case params
        case token
        case ref
        case union
        case unknown
        case record
        case query
        case procedure
        case subscription
    }

    private enum StringTypeCodingKeys: String, CodingKey {
        case format
    }

    private enum ArrayTypeCodingKeys: String, CodingKey {
        case items
    }

    private enum ObjectTypeCodingKeys: String, CodingKey {
        case properties
        case required
    }

    private enum RefTypeCodingKeys: String, CodingKey {
        case ref
    }

    private enum UnionTypeCodingKeys: String, CodingKey {
        case refs
    }

    private enum RecordTypeCodingKeys: String, CodingKey {
        case record
    }

    public init(from decoder: Decoder) throws {
        let typeContainer = try decoder.container(keyedBy: TypeCodingKeys.self)
        let type = try typeContainer.decode(LexiconType.self, forKey: .type)

        switch type {
        case .null:
            self = .null

        case .boolean:
            self = .boolean

        case .integer:
            self = .integer

        case .string:
            let container = try decoder.container(keyedBy: StringTypeCodingKeys.self)
            let format = try container.decodeIfPresent(String.self, forKey: .format)
            self = .string(format: format)

        case .bytes:
            self = .bytes

        case .cidLink:
            self = .cidLink

        case .blob:
            self = .blob

        case .array:
            let container = try decoder.container(keyedBy: ArrayTypeCodingKeys.self)
            let items = try container.decode(LexiconSchema.self, forKey: .items)
            self = .array(items)

        case .object:
            let object = try LexiconObjectSchema<Reference>(from: decoder)
            self = .object(object)

        case .params:
            self = .params

        case .token:
            self = .token

        case .ref:
            let container = try decoder.container(keyedBy: RefTypeCodingKeys.self)
            let id = try container.decode(String.self, forKey: .ref)
            self = .ref(try Reference(rawValue: id))

        case .union:
            let container = try decoder.container(keyedBy: UnionTypeCodingKeys.self)
            let refs = try container.decode([String].self, forKey: .refs)
            self = try .union(refs.map { try Reference(rawValue: $0) })

        case .unknown:
            self = .unknown

        case .record:
            let container = try decoder.container(keyedBy: RecordTypeCodingKeys.self)
            let object = try container.decode(LexiconObjectSchema<Reference>.self, forKey: .record)
            self = .record(object)

        case .query:
            let method = try LexiconMethodSchema<Reference>(from: decoder)
            self = .query(method)

        case .procedure:
            let method = try LexiconMethodSchema<Reference>(from: decoder)
            self = .procedure(method)

        case .subscription:
            self = .subscription
        }
    }
}

public extension LexiconSchema {
    var isNull: Bool {
        guard case .null = self else {
            return false
        }
        return true
    }

    var isObject: Bool {
        guard case .object = self else {
            return false
        }
        return true
    }

    var isRecord: Bool {
        guard case .record = self else {
            return false
        }
        return true
    }

    var isQuery: Bool {
        guard case .query = self else {
            return false
        }
        return true
    }

    func transformToAbsoluteReference(nsid: NSID) throws -> LexiconSchema<LexiconAbsoluteReference>
    {
        switch self {
        case .null:
            return .null

        case .boolean:
            return .boolean

        case .integer:
            return .integer

        case .string(let format):
            return .string(format: format)

        case .bytes:
            return .bytes

        case .cidLink:
            return .cidLink

        case .blob:
            return .blob

        case .array(let schema):
            return .array(try schema.transformToAbsoluteReference(nsid: nsid))

        case .object(let object):
            return .object(try object.transformToAbsoluteReference(nsid: nsid))

        case .params:
            return .params

        case .token:
            return .token

        case .ref(let ref):
            return .ref(try ref.absoluteReference(nsid: nsid))

        case .union(let refs):
            return try .union(refs.map { try $0.absoluteReference(nsid: nsid) })

        case .unknown:
            return .unknown

        case .record(let object):
            return .record(try object.transformToAbsoluteReference(nsid: nsid))

        case .query(let method):
            return .query(try method.transformToAbsoluteReference(nsid: nsid))

        case .procedure(let method):
            return .procedure(try method.transformToAbsoluteReference(nsid: nsid))

        case .subscription:
            return .subscription
        }
    }
}
