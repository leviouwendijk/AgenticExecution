import Agentic
import Schema

/// Immutable inspection snapshot for one ToolRegistry.
public struct AgentToolRegistryInspection:
    Sendable
{
    public let totalCount: Int
    public let tools: [AgentToolRegistryInspectionEntry]

    public init(
        totalCount: Int,
        tools: [AgentToolRegistryInspectionEntry]
    ) {
        self.totalCount = totalCount
        self.tools = tools
    }
}

/// Host-facing inspection facts captured from one registered tool capability.
public struct AgentToolRegistryInspectionEntry:
    Sendable
{
    public let identifier: AgentToolIdentifier
    public let description: String
    public let risk: ActionRisk
    public let isModelFacing: Bool
    public let workingLocation:
        AgentToolExecutionContract.WorkingLocation
    public let semanticInputSchema: JSONSchema?

    public init(
        identifier: AgentToolIdentifier,
        description: String,
        risk: ActionRisk,
        isModelFacing: Bool,
        workingLocation:
            AgentToolExecutionContract.WorkingLocation,
        semanticInputSchema: JSONSchema?
    ) {
        self.identifier = identifier
        self.description = description
        self.risk = risk
        self.isModelFacing = isModelFacing
        self.workingLocation = workingLocation
        self.semanticInputSchema = semanticInputSchema
    }

    public init(
        capability: AgentToolCapability
    ) {
        self.init(
            identifier: capability.definition.identifier,
            description: capability.definition.description,
            risk: capability.definition.risk,
            isModelFacing: capability.isModelFacing,
            workingLocation:
                capability.execution.workingLocation,
            semanticInputSchema:
                capability.semanticInputSchema
        )
    }
}

public extension ToolRegistry {
    /// Inspect every currently registered tool without changing model exposure.
    func inspect()
        -> AgentToolRegistryInspection
    {
        .init(
            totalCount: count,
            tools: capabilities.map { capability in
                AgentToolRegistryInspectionEntry(
                    capability: capability
                )
            }
        )
    }

    /// Inspect one exact registered tool identifier.
    func inspect(
        identifiedBy identifier: AgentToolIdentifier
    ) -> AgentToolRegistryInspectionEntry? {
        registeredTool(
            identifiedBy: identifier
        ).map { registered in
            AgentToolRegistryInspectionEntry(
                capability: registered.capability
            )
        }
    }
}
