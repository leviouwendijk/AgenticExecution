import Agentic

public enum AgentToolExposurePolicy:
    Sendable,
    Codable,
    Hashable
{
    case all
    case explicit(
        [AgentToolIdentifier]
    )
    case discoverable(
        [AgentToolIdentifier]
    )
}
