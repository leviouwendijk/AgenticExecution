import Agentic
import Workspace
import Primitives

public struct ToolRegistry: Sendable, ToolAvailability {
    private var tools:
        [ToolIdentifier: RegisteredAgentTool]

    public init() {
        self.tools = [:]
    }

    public var definitions: [ToolDescriptor] {
        tools.values
            .map(
                \.capability.definition
            )
            .sorted { lhs, rhs in
                lhs.name < rhs.name
            }
    }

    public var modelFacingDefinitions: [ToolDescriptor] {
        capabilities.compactMap { capability in
            guard capability.isModelFacing else {
                return nil
            }

            return capability.definition
        }
    }

    public func modelFacingDefinition(
        identifiedBy identifier: ToolIdentifier
    ) -> ToolDescriptor? {
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
        for identifiers: [ToolIdentifier]
    ) throws -> [ToolDescriptor] {
        var seen:
            Set<ToolIdentifier> = []
        var definitions:
            [ToolDescriptor] = []

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
        _ tool: T,
        modelContract: AgentToolModelContract? = nil,
        execution: AgentToolExecutionContract = .fixed
    ) throws where T: Tool {
        try register(
            RegisteredAgentTool(
                tool,
                modelContract: modelContract,
                execution: execution
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
        from provider: any AgentToolProvider
    ) throws {
        try provider.registerTools(
            into: &self
        )
    }

    public func registeredTool(
        identifiedBy identifier: ToolIdentifier
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
        _ call: ToolCall
    ) throws -> ParsedAgentToolCall {
        guard let registered =
            registeredTool(
                named: call.tool.rawValue
            )
        else {
            throw RegisteredAgentToolError
                .invalidModelCall(
                    tool: call.tool.rawValue,
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
        _ toolCall: ToolCall,
        workspace: WorkspaceContext? = nil
    ) async throws -> ToolPreflight {
        guard let registered =
            registeredTool(
                named: toolCall.tool.rawValue
            )
        else {
            throw ToolRegistryExecutionError.missingTool(
                toolCall.tool.rawValue
            )
        }

        return try await registered.preflight(
            toolCall,
            workspace: workspace
        )
    }

    public func call(
        _ toolCall: ToolCall,
        workspace: WorkspaceContext?
    ) async throws -> AgentToolExecutionResult {
        try await execute(
            toolCall,
            workspace: workspace
        )
    }
}
