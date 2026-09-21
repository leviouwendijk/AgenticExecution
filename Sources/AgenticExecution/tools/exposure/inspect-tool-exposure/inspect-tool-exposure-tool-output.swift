import Agentic
import Schema

public struct InspectToolExposureToolOutput:
    Sendable,
    Codable,
    Hashable,
    JSONSchemaProviding
{
    public let policy: AgentToolExposurePolicy
    public let registeredModelFacingCount: Int
    public let exposedCount: Int
    public let hiddenCount: Int
    public let exposedIdentifiers: [ToolIdentifier]
    public let seededIdentifiers: [ToolIdentifier]
    public let activatedIdentifiers: [ToolIdentifier]
    public let hiddenIdentifiers: [ToolIdentifier]?

    public init(
        inspection: AgentToolExposureInspection,
        includeHiddenIdentifiers: Bool
    ) {
        policy = inspection.policy
        registeredModelFacingCount =
            inspection.registeredModelFacingCount
        exposedCount = inspection.exposedCount
        hiddenCount = inspection.hiddenCount
        exposedIdentifiers = inspection.exposedIdentifiers
        seededIdentifiers = inspection.seededIdentifiers
        activatedIdentifiers = inspection.activatedIdentifiers
        hiddenIdentifiers = includeHiddenIdentifiers
            ? inspection.hiddenIdentifiers
            : nil
    }

    public static var jsonschema: JSONSchema {
        .any
    }
}
