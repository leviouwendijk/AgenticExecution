import Agentic

public struct AgentToolExposureInspection:
    Sendable,
    Codable,
    Hashable
{
    public let policy: AgentToolExposurePolicy
    public let registeredModelFacingCount: Int
    public let exposedIdentifiers: [AgentToolIdentifier]
    public let hiddenIdentifiers: [AgentToolIdentifier]
    public let seededIdentifiers: [AgentToolIdentifier]
    public let activatedIdentifiers: [AgentToolIdentifier]

    public var exposedCount: Int {
        exposedIdentifiers.count
    }

    public var hiddenCount: Int {
        hiddenIdentifiers.count
    }

    public init(
        policy: AgentToolExposurePolicy,
        registeredModelFacingCount: Int,
        exposedIdentifiers: [AgentToolIdentifier],
        hiddenIdentifiers: [AgentToolIdentifier],
        seededIdentifiers: [AgentToolIdentifier],
        activatedIdentifiers: [AgentToolIdentifier]
    ) {
        self.policy = policy
        self.registeredModelFacingCount = registeredModelFacingCount
        self.exposedIdentifiers = exposedIdentifiers
        self.hiddenIdentifiers = hiddenIdentifiers
        self.seededIdentifiers = seededIdentifiers
        self.activatedIdentifiers = activatedIdentifiers
    }
}
