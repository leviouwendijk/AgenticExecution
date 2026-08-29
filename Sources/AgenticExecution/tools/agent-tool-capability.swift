import Agentic
import Schema

/// Host-facing execution capability captured from one RegisteredAgentTool.
public struct AgentToolCapability:
    Sendable
{
    public let definition: AgentToolDefinition
    public let modelContract: AgentToolModelContract
    public let supportsWorkspaceTargeting: Bool

    public init(
        definition: AgentToolDefinition,
        modelContract: AgentToolModelContract,
        supportsWorkspaceTargeting: Bool
    ) {
        self.definition = definition
        self.modelContract = modelContract
        self.supportsWorkspaceTargeting = supportsWorkspaceTargeting
    }

    public var semanticInputSchema: JSONSchema? {
        modelContract.semanticInputSchema
    }

    public var isModelFacing: Bool {
        modelContract.isModelFacing
    }
}
