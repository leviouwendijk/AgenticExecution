import Agentic
import AgenticWorkspace
import Primitives

public struct ToolRegistry: Sendable {
    private var tools:
        [AgentToolIdentifier: RegisteredAgentTool]

    public init() {
        self.tools = [:]
    }

    public var definitions: [AgentToolDefinition] {
        tools.values
            .map(
                \.capability.definition
            )
            .sorted { lhs, rhs in
                lhs.name < rhs.name
            }
    }

    public var modelFacingDefinitions: [AgentToolDefinition] {
        capabilities.compactMap { capability in
            guard capability.isModelFacing else {
                return nil
            }

            return capability.definition
        }
    }

    public func modelFacingDefinition(
        identifiedBy identifier: AgentToolIdentifier
    ) -> AgentToolDefinition? {
        guard let registered =
            registeredTool(
                identifiedBy: identifier
            ),
            registered.capability.isModelFacing
        else {
            return nil
        }

        return registered.capability.definition
    }

    public func modelFacingDefinitions(
        for identifiers: [AgentToolIdentifier]
    ) throws -> [AgentToolDefinition] {
        var seen:
            Set<AgentToolIdentifier> = []
        var definitions:
            [AgentToolDefinition] = []

        for identifier in identifiers {
            guard seen.insert(
                identifier
            ).inserted else {
                continue
            }

            guard let definition =
                modelFacingDefinition(
                    identifiedBy: identifier
                )
            else {
                throw ToolRegistryError
                    .missingModelFacingTool(
                        identifier.rawValue
                    )
            }

            definitions.append(
                definition
            )
        }

        return definitions.sorted { lhs, rhs in
            lhs.name < rhs.name
        }
    }

    public var capabilities: [AgentToolCapability] {
        tools.values
            .map(
                \.capability
            )
            .sorted { lhs, rhs in
                lhs.definition.name
                    < rhs.definition.name
            }
    }

    public var isEmpty: Bool {
        tools.isEmpty
    }

    public var count: Int {
        tools.count
    }

    public mutating func register<T>(
        _ tool: T
    ) throws where T: AgentTool {
        try register(
            RegisteredAgentTool(
                tool
            )
        )
    }

    public mutating func register(
        _ registered: RegisteredAgentTool
    ) throws {
        let identifier =
            registered.capability.definition.identifier

        guard tools[identifier] == nil else {
            throw ToolRegistryError.duplicateTool(
                identifier.rawValue
            )
        }

        tools[identifier] = registered
    }

    public mutating func register(
        _ toolSet: any AgentToolSet
    ) throws {
        try toolSet.register(
            into: &self
        )
    }

    public mutating func register(
        from provider: any AgentToolProvider
    ) throws {
        try provider.registerTools(
            into: &self
        )
    }

    public func registeredTool(
        identifiedBy identifier: AgentToolIdentifier
    ) -> RegisteredAgentTool? {
        tools[identifier]
    }

    public func registeredTool(
        named name: String
    ) -> RegisteredAgentTool? {
        registeredTool(
            identifiedBy:
                .init(
                    name
                )
        )
    }

    public func parseModelCall(
        _ call: AgentToolCall
    ) throws -> ParsedAgentToolCall {
        guard let registered =
            registeredTool(
                named: call.name
            )
        else {
            throw RegisteredAgentToolError
                .invalidModelCall(
                    tool: call.name,
                    reason:
                        "No registered tool has this identifier."
                )
        }

        return try registered
            .parseModelCall(
                call
            )
    }

    public func preflight(
        _ toolCall: AgentToolCall,
        workspace: AgentWorkspace? = nil
    ) async throws -> ToolPreflight {
        try await preflight(
            toolCall,
            context: .init(
                workspace: workspace
            )
        )
    }

    public func preflight(
        _ toolCall: AgentToolCall,
        context: AgentToolExecutionContext
    ) async throws -> ToolPreflight {
        guard let registered =
            registeredTool(
                named: toolCall.name
            )
        else {
            throw ToolDispatchError.unknownTool(
                toolCall.name
            )
        }

        return try await registered.preflight(
            toolCall,
            context: context
        )
    }

    public func call(
        _ toolCall: AgentToolCall,
        workspace: AgentWorkspace?
    ) async throws -> AgentToolResult {
        try await execute(
            toolCall,
            context: .init(
                workspace: workspace
            )
        )
    }
}
