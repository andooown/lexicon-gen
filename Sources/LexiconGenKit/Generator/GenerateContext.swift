import LexiconGenKit

class NamespaceNode: Equatable {
    let name: String
    private(set) var children = [NamespaceNode]()
    weak var parent: NamespaceNode?

    init(name: String) {
        self.name = name
    }

    var isRoot: Bool {
        self == .root
    }

    var allNodes: [NamespaceNode] {
        var nodes = isRoot ? [] : [self]
        for child in children {
            nodes.append(contentsOf: child.allNodes)
        }

        return nodes
    }

    var namespace: String {
        var names = [String]()

        var target = self
        while let n = target.parent {
            names.append(n.name)
            target = n
        }
        names.reverse()

        return names.filter { !$0.isEmpty }.joined(separator: ".")
    }

    var fullName: String {
        [namespace, name].filter { !$0.isEmpty }.joined(separator: ".")
    }

    func addNode(names: [String]) {
        guard !names.isEmpty else {
            return
        }

        var names = names
        let name = names.removeFirst()

        let target: NamespaceNode
        if let child = children.first(where: { $0.name == name }) {
            target = child
        } else {
            let child = NamespaceNode(name: name)
            child.parent = self
            children.append(child)

            target = child
        }

        target.addNode(names: names)
    }

    static var root: NamespaceNode {
        NamespaceNode(name: "")
    }

    static func == (lhs: NamespaceNode, rhs: NamespaceNode) -> Bool {
        lhs.name == rhs.name
            && lhs.children.count == rhs.children.count
            && zip(lhs.children, rhs.children).allSatisfy { $0 == $1 }
            && lhs.parent == rhs.parent
    }
}

public struct SwiftNamespaceDefinition {
    public let parent: String
    public let name: String

    public init(parent: String, name: String) {
        self.parent = parent
        self.name = name
    }

    public var fullName: String {
        parent + "." + name
    }
}

public struct SwiftDefinition<Object> {
    public let id: LexiconDefinitionID
    public let parent: String
    public let name: String
    public let object: Object

    public init(
        id: LexiconDefinitionID,
        parent: String,
        name: String,
        object: Object
    ) {
        self.id = id
        self.parent = parent
        self.name = name
        self.object = object
    }

    public var fullName: String {
        parent + "." + name
    }
}

public class GenerateContext {
    private let docs = LexiconDocumentCollection<LexiconAbsoluteReference>()

    public init() {}

    public func append(_ doc: LexiconDocument<LexiconAbsoluteReference>) {
        docs.add(doc)
    }

    public func generateNamespaceDefinitions() -> [SwiftNamespaceDefinition] {
        let defs = generateDefinitions()

        let rootNode = NamespaceNode.root
        for def in defs {
            rootNode.addNode(names: def.parent.components(separatedBy: "."))
        }

        let namespaces = Set(rootNode.allNodes.map(\.fullName).filter { !$0.isEmpty })
        let definitions = Set(defs.map(\.fullName))
        return namespaces.subtracting(definitions)
            .sorted()
            .compactMap { namespace in
                guard let (parent, name) = separateFullName(namespace) else {
                    return nil
                }

                return SwiftNamespaceDefinition(parent: parent, name: name)
            }
    }

    public func generateDefinitions() -> [SwiftDefinition<LexiconSchema<LexiconAbsoluteReference>>] {
        docs.generateDefinitions()
            .sorted { $0.key.value < $1.key.value }
            .map { key, value in
                let (parent, name) = key.swiftDefinitionNames
                return SwiftDefinition(id: key, parent: parent, name: name, object: value)
            }
    }

    private func separateFullName(_ fullName: String) -> (parent: String, name: String)? {
        var components = fullName.components(separatedBy: ".")
        guard components.count >= 1 else {
            return nil
        }

        let name = components.removeLast()
        return (components.joined(separator: "."), name)
    }
}

public extension LexiconDefinitionID {
    var swiftDefinitionNames: (parent: String, name: String) {
        var namespaceComponents = nsid.segments.map(\.headUppercased)
        if isMain {
            let name = namespaceComponents.popLast()!
            let parent = namespaceComponents.joined(separator: ".")
            return (parent, name)
        }

        return (
            namespaceComponents.joined(separator: "."),
            name.headUppercased
        )
    }
}
