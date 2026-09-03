public struct AgentToolExecutionContract:
    Sendable,
    Codable,
    Hashable
{
    public enum WorkingLocation:
        String,
        Sendable,
        Codable,
        Hashable,
        CaseIterable
    {
        case fixed
        case targetable
    }

    public let workingLocation: WorkingLocation

    public init(
        workingLocation: WorkingLocation = .fixed
    ) {
        self.workingLocation = workingLocation
    }

    public static let fixed = Self()

    public static let targetable = Self(
        workingLocation: .targetable
    )
}
