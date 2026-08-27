import Agentic
import Primitives

public protocol StaticAgentTool: Sendable, AgentTool {
    static var identifier: AgentToolIdentifier { get }
    static var description: String { get }
    static var inputSchema: JSONValue? { get }
    static var risk: ActionRisk { get }
}

public extension StaticAgentTool {
    static var inputSchema: JSONValue? {
        nil
    }

    var identifier: AgentToolIdentifier {
        Self.identifier
    }

    var description: String {
        Self.description
    }

    var inputSchema: JSONValue? {
        Self.inputSchema
    }

    var risk: ActionRisk {
        Self.risk
    }
}

public extension AgentToolReference {
    static func tool<T>(
        _ type: T.Type,
        owner: String? = nil
    ) -> Self where T: StaticAgentTool {
        .init(
            identifier: type.identifier,
            owner: owner
        )
    }
}
