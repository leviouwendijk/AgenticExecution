import Agentic

public enum AgentToolExposurePolicy:
    Sendable,
    Codable,
    Hashable
{
    case all
    case explicit(
        [ToolIdentifier]
    )
    case discoverable(
        [ToolIdentifier]
    )
}
