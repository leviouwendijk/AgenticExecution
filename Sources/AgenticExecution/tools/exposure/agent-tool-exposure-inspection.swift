import Agentic

public struct AgentToolExposureInspection:
    Sendable,
    Codable,
    Hashable
{
    public let policy: AgentToolExposurePolicy
    public let registeredModelFacingCount: Int
    public let exposedIdentifiers: [ToolIdentifier]
    public let hiddenIdentifiers: [ToolIdentifier]
    public let seededIdentifiers: [ToolIdentifier]
    public let activatedIdentifiers: [ToolIdentifier]

    public var exposedCount: Int {
        exposedIdentifiers.count
    }

    public var hiddenCount: Int {
        hiddenIdentifiers.count
    }

    public init(
        policy: AgentToolExposurePolicy,
        registeredModelFacingCount: Int,
        exposedIdentifiers: [ToolIdentifier],
        hiddenIdentifiers: [ToolIdentifier],
        seededIdentifiers: [ToolIdentifier],
        activatedIdentifiers: [ToolIdentifier]
    ) {
        self.policy = policy
        self.registeredModelFacingCount = registeredModelFacingCount
        self.exposedIdentifiers = exposedIdentifiers
        self.hiddenIdentifiers = hiddenIdentifiers
        self.seededIdentifiers = seededIdentifiers
        self.activatedIdentifiers = activatedIdentifiers
    }
}
