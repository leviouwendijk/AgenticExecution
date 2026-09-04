import Agentic

public struct InspectToolExposureToolOutput:
    Sendable,
    Codable,
    Hashable
{
    public let policy: AgentToolExposurePolicy
    public let registeredModelFacingCount: Int
    public let exposedCount: Int
    public let hiddenCount: Int
    public let exposedIdentifiers: [AgentToolIdentifier]
    public let seededIdentifiers: [AgentToolIdentifier]
    public let activatedIdentifiers: [AgentToolIdentifier]
    public let hiddenIdentifiers: [AgentToolIdentifier]?

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
}
