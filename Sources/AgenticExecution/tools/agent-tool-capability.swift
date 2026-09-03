import Agentic
import Schema

/// Host-facing capability captured from one RegisteredAgentTool.
public struct AgentToolCapability:
    Sendable
{
    public let definition: AgentToolDefinition
    public let modelContract: AgentToolModelContract
    public let execution: AgentToolExecutionContract

    public init(
        definition: AgentToolDefinition,
        modelContract: AgentToolModelContract,
        execution: AgentToolExecutionContract
    ) {
        self.definition = definition
        self.modelContract = modelContract
        self.execution = execution
    }

    public var semanticInputSchema: JSONSchema? {
        modelContract.semanticInputSchema
    }

    public var isModelFacing: Bool {
        modelContract.isModelFacing
    }
}
