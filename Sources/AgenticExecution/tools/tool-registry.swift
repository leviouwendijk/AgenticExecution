import Agentic
import AgenticWorkspace

public struct ToolRegistry: Sendable {
    private var tools: [AgentToolIdentifier: any AgentTool]

    public init(
        tools: [any AgentTool] = []
    ) {
        self.tools = Dictionary(
            uniqueKeysWithValues: tools.map { tool in
                (tool.identifier, tool)
            }
        )
    }

    public var definitions: [AgentToolDefinition] {
        tools.values.map(\.definition).sorted { lhs, rhs in
            lhs.name < rhs.name
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

        tools[identifier] = tool
    }

    public mutating func register(
        _ tools: [any AgentTool]
    ) throws {
        for tool in tools {
            try register(tool)
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

    public func tool(
        identifiedBy identifier: AgentToolIdentifier
    ) -> (any AgentTool)? {
        tools[identifier]
    }

    public func tool(
        named name: String
    ) -> (any AgentTool)? {
        tool(
            identifiedBy: .init(name)
        )
    }

    public func preflight(
        _ toolCall: AgentToolCall,
        workspace: AgentWorkspace? = nil
    ) async throws -> ToolPreflight {
        guard let tool = tool(named: toolCall.name) else {
            throw ToolDispatchError.unknownTool(toolCall.name)
        }

        return try await tool.preflight(
            input: toolCall.input,
            workspace: workspace
        )
    }

    public func call(
        _ toolCall: AgentToolCall,
        workspace: AgentWorkspace?
    ) async throws -> AgentToolResult {
        guard let tool = tool(named: toolCall.name) else {
            throw ToolDispatchError.unknownTool(toolCall.name)
        }

        let output = try await tool.call(
            input: toolCall.input,
            workspace: workspace
        )

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
                    : processing
        )
    }
}
