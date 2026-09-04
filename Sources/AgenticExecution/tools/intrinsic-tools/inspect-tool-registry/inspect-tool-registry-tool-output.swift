import Agentic
import Primitives

public struct InspectedAgentTool:
    Sendable,
    Codable,
    Hashable
{
    public let identifier: AgentToolIdentifier
    public let description: String
    public let risk: ActionRisk
    public let modelFacing: Bool
    public let workingLocation:
        AgentToolExecutionContract.WorkingLocation
    public let hasSemanticInputSchema: Bool
    public let semanticInputSchema: JSONValue?

    public init(
        identifier: AgentToolIdentifier,
        description: String,
        risk: ActionRisk,
        modelFacing: Bool,
        workingLocation:
            AgentToolExecutionContract.WorkingLocation,
        hasSemanticInputSchema: Bool,
        semanticInputSchema: JSONValue? = nil
    ) {
        self.identifier = identifier
        self.description = description
        self.risk = risk
        self.modelFacing = modelFacing
        self.workingLocation = workingLocation
        self.hasSemanticInputSchema = hasSemanticInputSchema
        self.semanticInputSchema = semanticInputSchema
    }
}

public struct InspectToolRegistryToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let totalCount: Int
    public let returnedCount: Int
    public let tools: [InspectedAgentTool]

    public init(
        totalCount: Int,
        returnedCount: Int,
        tools: [InspectedAgentTool]
    ) {
        self.totalCount = totalCount
        self.returnedCount = returnedCount
        self.tools = tools
    }
}
