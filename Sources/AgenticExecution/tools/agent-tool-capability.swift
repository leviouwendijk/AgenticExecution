import Agentic
import Schema

/// Host-facing execution capability projected from one registered tool.
/// Execution metadata remains separate from the semantic AgentToolDefinition.
public struct AgentToolCapability: Sendable {
    public let definition: AgentToolDefinition
    public let semanticInputSchema: JSONSchema?
    public let supportsWorkspaceTargeting: Bool

    public init(
        definition: AgentToolDefinition,
        semanticInputSchema: JSONSchema?,
        supportsWorkspaceTargeting: Bool
    ) {
        self.definition = definition
        self.semanticInputSchema = semanticInputSchema
        self.supportsWorkspaceTargeting = supportsWorkspaceTargeting
    }
}

public extension AgentToolCapability {
    init(
        tool: any AgentTool
    ) {
        self.init(
            definition: tool.definition,
            semanticInputSchema: (tool as? any SchemaBackedAgentTool)?
                .semanticInputSchema,
            supportsWorkspaceTargeting:
                tool is any WorkspaceTargetableTool
        )
    }
}
