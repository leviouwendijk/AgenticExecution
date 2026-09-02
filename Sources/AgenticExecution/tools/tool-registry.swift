import Agentic
import AgenticWorkspace
import Primitives

public struct ToolRegistry: Sendable {
    private var tools:
        [AgentToolIdentifier: RegisteredAgentTool]

    public init(
        tools: [any AgentTool] = []
    ) {
        self.tools = Dictionary(
            uniqueKeysWithValues:
                tools.map { tool in
                    let registered =
                        RegisteredAgentTool(
                            tool
                        )

                    return (
                        tool.identifier,
                        registered
                    )
                }
        )
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

    public mutating func register(
        _ tool: any AgentTool
    ) throws {
        let identifier = tool.identifier

        guard tools[identifier] == nil else {
            throw ToolRegistryError.duplicateTool(
                identifier.rawValue
            )
        }

        tools[identifier] =
            RegisteredAgentTool(
                tool
            )
    }

    public mutating func register(
        _ tools: [any AgentTool]
    ) throws {
        for tool in tools {
            try register(
                tool
            )
        }
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

    public func tool(
        identifiedBy identifier: AgentToolIdentifier
    ) -> (any AgentTool)? {
        registeredTool(
            identifiedBy: identifier
        )?
        .tool
    }

    public func tool(
        named name: String
    ) -> (any AgentTool)? {
        registeredTool(
            named: name
        )?
        .tool
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
        guard let tool = tool(
            named: toolCall.name
        ) else {
            throw ToolDispatchError.unknownTool(
                toolCall.name
            )
        }

        return try await tool.preflight(
            input: toolCall.input,
            context:
                context.withToolCallID(
                    toolCall.id
                )
        )
    }

    public func call(
        _ toolCall: AgentToolCall,
        workspace: AgentWorkspace?
    ) async throws -> AgentToolResult {
        guard let tool = tool(
            named: toolCall.name
        ) else {
            throw ToolDispatchError.unknownTool(
                toolCall.name
            )
        }

        let output: JSONValue
        let isError: Bool

        do {
            output = try await tool.call(
                input: toolCall.input,
                workspace: workspace
            )
            isError = false
        } catch let failure
            as AgentToolReportedFailure
        {
            output = failure.output
            isError = true
        }

        let processing = tool.processResult(
            input: toolCall.input,
            output: output,
            workspace: workspace
        )

        return AgentToolResult(
            toolCallID: toolCall.id,
            name: tool.identifier.rawValue,
            output: output,
            processing:
                processing.isEmpty
                    ? nil
                    : processing,
            isError: isError
        )
    }
}
