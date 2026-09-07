import Primitives

public struct AgentToolCollectionIdentifier:
    StringIdentifier
{
    public let rawValue: String

    public init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

public enum AgentToolDefaultExposure:
    String,
    Sendable,
    Codable,
    Hashable
{
    case included
    case excluded
}

public struct AgentToolCollectionMetadata:
    Sendable,
    Hashable
{
    public let identifier: AgentToolCollectionIdentifier
    public let title: String
    public let defaultExposure: AgentToolDefaultExposure

    public init(
        identifier: AgentToolCollectionIdentifier,
        title: String,
        defaultExposure: AgentToolDefaultExposure = .included
    ) {
        self.identifier = identifier
        self.title = title
        self.defaultExposure = defaultExposure
    }

    public static let ungrouped = Self(
        identifier: .init(
            rawValue: "agentic.ungrouped"
        ),
        title: "Application",
        defaultExposure: .included
    )

    public static let intrinsics = Self(
        identifier: .init(
            rawValue: "agentic.intrinsics"
        ),
        title: "Intrinsics",
        defaultExposure: .excluded
    )
}
